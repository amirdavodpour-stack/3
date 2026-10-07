// Offer lifecycle routes.

export function createOfferRoutes({ authUser, readBody, sendJson, HttpError, requireFields, textField, moneyField, tomanField, repo, legacy, id, getJob, getUserById, enforceJobState, createAudit, now, jobView, ensureJobChat }) {
  const enrichOffer = async (offer, me, job = null) => {
    if (!offer) return offer;
    const resolvedJob = job || await getJob(offer.jobId);
    const counterpartyId = String(offer.providerId) === String(me.id)
      ? resolvedJob?.ownerId
      : offer.providerId;
    const counterparty = counterpartyId && typeof getUserById === 'function'
      ? await getUserById(counterpartyId)
      : null;
    return {
      ...offer,
      jobTitle: resolvedJob?.title || null,
      counterpartyName: counterparty?.displayName || null,
    };
  };

  return async function routeHandler(req, res, parts) {
    // Read-only offer views are deliberately scoped to the authenticated viewer:
    // job owners can see all offers on their jobs; providers can only see their own.
    if (req.method === 'GET' && parts.length === 1) {
      const me = await authUser(req);
      const jobId = new URL(req.url, 'http://localhost').searchParams.get('jobId');
      if (!jobId) throw new HttpError(400, 'JOB_ID_REQUIRED', 'jobId query parameter is required');
      const job = await getJob(String(jobId));
      if (!job) throw new HttpError(404, 'JOB_NOT_FOUND', 'Job not found');
      if (job.ownerId !== me.id) {
        const own = process.env.DATABASE_URL
          ? await repo.findPendingOffer(job.id, me.id)
          : legacy.findPending(job.id, me.id);
        return sendJson(res, 200, { items: own ? [await enrichOffer(own, me, job)] : [] });
      }
      const items = process.env.DATABASE_URL
        ? await repo.findOffers(job.id)
        : legacy.listForJob(job.id);
      const enriched = await Promise.all(items.map((offer) => enrichOffer(offer, me, job)));
      return sendJson(res, 200, { items: enriched });
    }
    if (req.method === 'GET' && parts.length === 2 && parts[1] === 'mine') {
      const me = await authUser(req);
      if (process.env.DATABASE_URL) {
        const items = await repo.listOffersForProvider(me.id);
        const enriched = await Promise.all(items.map((offer) => enrichOffer(offer, me)));
        return sendJson(res, 200, { items: enriched });
      }
      return sendJson(res, 200, { items: legacy.listForProvider(me.id) });
    }
    if (req.method === 'GET' && parts.length === 2) {
      const me = await authUser(req);
      const offer = process.env.DATABASE_URL ? await repo.findOfferById(parts[1]) : legacy.findById(parts[1]);
      if (!offer) throw new HttpError(404, 'OFFER_NOT_FOUND', 'Offer not found');
      const job = await getJob(offer.jobId);
      if (!job || (job.ownerId !== me.id && offer.providerId !== me.id)) {
        throw new HttpError(404, 'OFFER_NOT_FOUND', 'Offer not found');
      }
      return sendJson(res, 200, await enrichOffer(offer, me, job));
    }
    if (req.method === 'POST' && parts.length === 1) {
      const me = await authUser(req); const body = await readBody(req); requireFields(body, ['jobId', 'price']);
      const job = await getJob(String(body.jobId)); if (!job) throw new HttpError(404, 'JOB_NOT_FOUND', 'Job not found');
      if (job.ownerId === me.id) throw new HttpError(403, 'FORBIDDEN', 'Owners cannot submit offers to their own job');
      enforceJobState(job, ['PUBLISHED']);
      const price = tomanField ? tomanField(body.price, 'price') : moneyField(body.price, 'price');
      const message = body.message ? textField(body.message, 'message', { min: 1, max: 4000 }) : '';
      const existing = process.env.DATABASE_URL ? await repo.findPendingOffer(job.id,me.id) : legacy.findPending(job.id, me.id);
      if (existing) throw new HttpError(409, 'OFFER_EXISTS', 'You already have a pending offer for this job');
      const offerDraft = { id: (process.env.DATABASE_URL ? id : legacy.newId)(), jobId: job.id, providerId: me.id, price, message, status: 'PENDING', createdAt: now(), updatedAt: now() };
      let offer;
      try { offer = process.env.DATABASE_URL ? await repo.insertOffer(offerDraft) : legacy.create(offerDraft); }
      catch (error) { if (error?.code === 'OFFER_EXISTS') throw new HttpError(409, 'OFFER_EXISTS', 'You already have a pending offer for this job'); throw error; }
      await createAudit('OFFER_CREATE', me.id, 'offer', offer.id, { jobId: job.id });
      return sendJson(res, 201, await enrichOffer(offer, me, job));
    }
    if (req.method === 'POST' && parts[2] === 'accept') {
      const me = await authUser(req); const offer = process.env.DATABASE_URL ? await repo.findOfferById(parts[1]) : legacy.findById(parts[1]); if (!offer) throw new HttpError(404, 'OFFER_NOT_FOUND', 'Offer not found');
      const job = await getJob(offer.jobId); if (!job || job.ownerId !== me.id) throw new HttpError(403, 'FORBIDDEN', 'Only the job owner can accept an offer');
      enforceJobState(job, ['PUBLISHED']);
      if (process.env.DATABASE_URL) {
        const result = await repo.acceptOffer(offer.id, me.id);
        if (!result) throw new HttpError(404, 'OFFER_NOT_FOUND', 'Offer not found');
        await createAudit('OFFER_ACCEPT', me.id, 'offer', offer.id, { jobId: job.id });
        if (typeof ensureJobChat === 'function') await ensureJobChat(job.id);
        return sendJson(res, 200, { offer: result.offer, job: await jobView(result.job, me.id) });
      }
      const accepted = await legacy.accept(offer, job, () => createAudit('OFFER_ACCEPT', me.id, 'offer', offer.id, { jobId: job.id }));
      await legacy.save();
      return sendJson(res, 200, { offer: accepted.offer, job: await jobView(accepted.job, me.id) });
    }
    throw new HttpError(404, 'NOT_FOUND', 'Offer route not found');
  };
}
