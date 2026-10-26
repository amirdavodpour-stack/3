import { normalizeChatMessageType } from '../services/human_chat.js';
const ROUTE_MESSAGE='Messaging route not found';
export function createHumanChatRoutes({authUser,sendJson,readBody,HttpError,repo,storage}){
  return async function route(req,res,parts){
    const me=await authUser(req);
    if(parts[0]!=='messaging')throw new HttpError(404,'NOT_FOUND',ROUTE_MESSAGE);
    if(parts.length===2&&parts[1]==='conversations'&&req.method==='GET')
      return sendJson(res,200,{items:await repo.listChatConversations(me.id,me.role)});
    if(parts.length===4&&parts[1]==='attachments'&&parts[3]==='content'&&req.method==='GET'){
      const a=await repo.getChatAttachmentForUser(parts[2],me.id,me.role);
      if(!a)throw new HttpError(404,'CHAT_ATTACHMENT_NOT_FOUND','Attachment not found');
      let object;try{object=await storage.get({key:a.storageKey});}catch{throw new HttpError(404,'CHAT_ATTACHMENT_NOT_FOUND','Attachment not found');}
      if(!object?.body||typeof object.body.pipe!=='function')
        throw new HttpError(500,'CHAT_ATTACHMENT_STREAM_UNAVAILABLE','Attachment stream is unavailable');
      res.writeHead(200,{'Content-Type':a.contentType,'Content-Length':String(a.size||object.size||0),
        'Content-Disposition':"inline; filename*=UTF-8''"+encodeURIComponent(a.filename),
        'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'});
      object.body.on('error',e=>res.destroy(e));object.body.pipe(res);return;
    }
    if(parts.length>=3&&parts[1]==='conversations'){
      const id=parts[2];
      if(parts.length===3&&req.method==='GET'){
        const result=await repo.listChatMessages(id,me.id,me.role);
        if(!result)throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');
        return sendJson(res,200,result);
      }
      if(parts.length===3&&req.method==='POST'){
        const body=await readBody(req),message=String(body?.message||'').trim();
        const messageType=normalizeChatMessageType(body?.messageType||'TEXT');
        const attachments=Array.isArray(body?.attachments)?body.attachments:[];
        if(!message&&attachments.length===0)throw new HttpError(400,'MESSAGE_REQUIRED','Message or attachment is required');
        if(!messageType)throw new HttpError(400,'CHAT_MESSAGE_TYPE_INVALID','Unsupported message type');
        if(message.length>4000)throw new HttpError(400,'MESSAGE_TOO_LONG','Message is too long');
        if(attachments.length>5)throw new HttpError(400,'CHAT_TOO_MANY_ATTACHMENTS','A message can include up to five files');
        try{return sendJson(res,201,await repo.postChatMessage(id,me.id,me.role,message,{messageType,attachments}));}
        catch(error){
          if(error?.code==='CHAT_CLOSED_OR_FORBIDDEN')throw new HttpError(403,'CHAT_CLOSED_OR_FORBIDDEN','Conversation is closed or you are not a participant');
          if(error?.code?.startsWith('CHAT_')||error?.code==='MESSAGE_TOO_LONG')throw new HttpError(400,error.code,'Message or attachment is invalid');
          throw error;
        }
      }
      if(parts.length===4&&parts[3]==='read'&&req.method==='POST'){
        const result=await repo.markChatConversationRead(id,me.id,me.role);
        if(!result)throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');
        return sendJson(res,200,result);
      }
      if(parts.length===4&&parts[3]==='presence'){
        if(req.method==='GET'){const result=await repo.listChatPresence(id,me.id,me.role);if(!result)throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');return sendJson(res,200,{items:result});}
        if(req.method==='POST'){const body=await readBody(req);const result=await repo.updateChatPresence(id,me.id,me.role,{online:body?.online!==false,typing:body?.typing===true});if(!result)throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');return sendJson(res,200,result);}
      }
      if(parts.length===4&&parts[3]==='preferences'&&req.method==='PATCH'){
        const body=await readBody(req);
        for(const field of ['isPinned','isImportant','isArchived'])if(body?.[field]!==undefined&&typeof body[field]!=='boolean')throw new HttpError(400,'CHAT_PREFERENCE_INVALID','Conversation preferences must be boolean');
        const result=await repo.updateChatConversationPreferences(id,me.id,me.role,body||{});
        if(!result)throw new HttpError(404,'CHAT_NOT_FOUND','Conversation not found');
        return sendJson(res,200,result);
      }
    }
    throw new HttpError(404,'NOT_FOUND',ROUTE_MESSAGE);
  };
}
