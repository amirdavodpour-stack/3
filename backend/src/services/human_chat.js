export const CHAT_KINDS = Object.freeze(['JOB','ADMIN']);
export const CHAT_STATUSES = Object.freeze(['OPEN','CLOSED']);
export const CHAT_MESSAGE_TYPES = Object.freeze(['TEXT','ATTACHMENT','VOICE']);
export const CHAT_ATTACHMENT_CONTENT_TYPES = Object.freeze([
  'application/pdf','image/png','image/jpeg','image/webp','text/plain','audio/mp4','audio/mpeg','audio/wav',
]);
const normalized=(value)=>String(value??'').trim().toUpperCase();
export function canAccessConversation(conversation,userId,role){
  if(!conversation||!userId)return false;
  const kind=normalized(conversation.kind);
  if(kind==='ADMIN')return normalized(role)==='ADMIN';
  if(kind==='JOB')return String(conversation.ownerId)===String(userId)||String(conversation.workerId)===String(userId);
  return false;
}
export function canSendToConversation(conversation,userId,role){
  return normalized(conversation?.status)==='OPEN'&&canAccessConversation(conversation,userId,role);
}
export function normalizeChatMessageType(value){
  const type=normalized(value||'TEXT');
  return CHAT_MESSAGE_TYPES.includes(type)?type:null;
}
export function isSupportedChatAttachment(contentType){
  return CHAT_ATTACHMENT_CONTENT_TYPES.includes(String(contentType??'').trim().toLowerCase());
}
export function canAttachToChat({messageType,contentTypes,text=''}){
  const type=normalizeChatMessageType(messageType);
  if(!type||!Array.isArray(contentTypes)||contentTypes.length>5)return false;
  if(type==='TEXT')return contentTypes.length===0&&String(text).trim().length>0;
  if(type==='ATTACHMENT')return contentTypes.length>0&&contentTypes.every(isSupportedChatAttachment);
  return type==='VOICE'&&contentTypes.length===1&&String(contentTypes[0]).startsWith('audio/')&&contentTypes.every(isSupportedChatAttachment);
}
