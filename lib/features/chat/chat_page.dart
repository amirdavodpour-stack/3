import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/network/api_error_presenter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.repository, this.jobId, this.adminRoom = false});
  final ChatRepository? repository;
  final String? jobId;
  final bool adminRoom;
  @override State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller=TextEditingController();
  final _scroll=ScrollController();
  late final ChatRepository _repository;
  HopeChatThread? _thread;
  bool _busy=false;
  String? _error;

  @override void initState(){super.initState(); _repository=widget.repository ?? context.read<ChatRepository>(); WidgetsBinding.instance.addPostFrameCallback((_)=>_load());}
  @override void dispose(){_controller.dispose();_scroll.dispose();super.dispose();}

  Future<void> _load() async {
    try {
      final items=await _repository.listConversations();
      HopeChatConversation? c;
      for (final item in items) {
        final matches = widget.adminRoom
            ? item.kind.toUpperCase() == 'ADMIN'
            : item.kind.toUpperCase() == 'JOB' && item.jobId == widget.jobId;
        if (matches) { c = item; break; }
      }
      if(c==null) throw StateError('Conversation is not available');
      final thread=await _repository.getMessages(c.id);
      if(mounted)setState(()=>_thread=thread);
    } catch(e){if(mounted)setState(()=>_error=apiErrorMessage(e,fallback:_t('گفتگو در دسترس نیست.','Conversation is not available.')));}
  }

  Future<void> _send() async {
    final text=_controller.text.trim();
    final thread=_thread;
    if(text.isEmpty||_busy||thread==null||thread.conversation.status.toUpperCase()!='OPEN')return;
    setState(()=>_busy=true); _controller.clear();
    try {
      final m=await _repository.sendMessage(thread.conversation.id,text);
      if(!mounted)return;
      setState(()=>_thread=HopeChatThread(conversation:thread.conversation,messages:[...thread.messages,m]));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(_scroll.hasClients)_scroll.animateTo(_scroll.position.maxScrollExtent,duration:const Duration(milliseconds:180),curve:Curves.easeOut);
      });
    } catch(e){if(mounted)setState(()=>_error=apiErrorMessage(e,fallback:_t('پیام ارسال نشد.','Message could not be sent.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  String _t(String fa,String en)=>Localizations.localeOf(context).languageCode=='en'?en:fa;

  @override Widget build(BuildContext context){
    final c=_thread?.conversation;
    final title=widget.adminRoom?_t('گفتگوی مدیران','Admin room'):c?.otherUserName.isNotEmpty==true?c!.otherUserName:_t('گفتگوی این کار','Job chat');
    return Scaffold(
      appBar:AppBar(title:Text(title)),
      body:SafeArea(child:Column(children:[
        if(_error!=null) Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        Expanded(child:_thread==null
          ? const Center(child:CircularProgressIndicator())
          : _thread!.messages.isEmpty
            ? Center(child:Text(_t('هنوز پیامی ثبت نشده است.','No messages yet.')))
            : ListView.builder(controller:_scroll,padding:const EdgeInsets.all(16),itemCount:_thread!.messages.length,itemBuilder:(context,i){
                final m=_thread!.messages[i];
                return Align(alignment:AlignmentDirectional.centerStart,child:Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(m.senderName,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(m.body)]))));
              })),
        if(c?.status.toUpperCase()=='OPEN') Padding(padding:const EdgeInsets.fromLTRB(12,8,12,14),child:Row(children:[
          Expanded(child:TextField(controller:_controller,maxLines:4,minLines:1,enabled:!_busy,onSubmitted:(_)=>_send(),decoration:InputDecoration(hintText:_t('پیام خود را بنویسید','Write a message'),border:const OutlineInputBorder()))),
          const SizedBox(width:8),
          IconButton.filled(onPressed:_busy?null:_send,tooltip:_t('ارسال','Send'),icon:const Icon(Icons.send_rounded))
        ]))
        else if(c!=null) Padding(padding:const EdgeInsets.all(16),child:Text(_t('این گفتگو با پایان کار و تسویه بسته شده است.','This conversation is closed because the job has ended and settled.')))
      ])),
    );
  }
}
