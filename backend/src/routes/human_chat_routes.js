import { canAccessConversation } from '../services/human_chat.js';

export function createHumanChatRoutes({ authUser, sendJson, readBody, HttpError, repo }) {
  return async function route(req, res, parts) {
    const me = await authUser(req);
    if (parts[0] !== 'messaging') throw new HttpError(404,'NOT_FOUND','Messaging route not found');
    if (parts.length === 2 && parts[1] === 'conversations' && req.method === 'GET') {
      return sendJson(res,200,{items:await repo.listChatConversations(me.id,me.role)});
    }
    if (parts.length === 3 && parts[1] === 'conversations') {
      const id=parts[2];
      if (req.method === 'GET') {
        const result=await repo.listChatMessages(id,me.id,me.role);
        if (!result) throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');
        return sendJson(res,200,result);
      }
      if (req.method === 'POST') {
        const body=await readBody(req);
        const message=String(body?.message||'').trim();
        if (!message) throw new HttpError(400,'MESSAGE_REQUIRED','Message is required');
        if (message.length>4000) throw new HttpError(400,'MESSAGE_TOO_LONG','Message is too long');
        try {
          const created=await repo.postChatMessage(id,me.id,me.role,message);
          return sendJson(res,201,created);
        } catch(error) {
          if (error?.code==='CHAT_CLOSED_OR_FORBIDDEN') throw new HttpError(403,'CHAT_CLOSED_OR_FORBIDDEN','Conversation is closed or you are not a participant');
          throw error;
        }
      }
    }
    throw new HttpError(404,'NOT_FOUND','Messaging route not found');
  };
}