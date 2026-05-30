import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';

const String kAgoraAppId = 'b686b1ec457344b29b45056e4b1fcec3';
enum CallType { voice, video }

class CallListenerWrapper extends StatefulWidget {
  final Widget child;
  const CallListenerWrapper({super.key, required this.child});
  @override State<CallListenerWrapper> createState() => _CLWState();
}
class _CLWState extends State<CallListenerWrapper> {
  StreamSubscription? _sub;
  final _db = FirebaseDatabase.instance;
  bool _showing = false;
  @override void initState() { super.initState(); _listen(); }
  void _listen() {
    final uid = AuthService().currentUid; if (uid == null) return;
    _sub = _db.ref('calls/$uid').onChildAdded.listen((e) async {
      if (!e.snapshot.exists || !mounted || _showing) return;
      final d = Map<String,dynamic>.from(e.snapshot.value as Map);
      if (d['status'] != 'ringing') return;
      _showing = true;
      final key = e.snapshot.key ?? '';
      final type = d['type'] == 'video' ? CallType.video : CallType.voice;
      await showDialog(context: context, barrierDismissible: false,
        builder: (_) => IncomingCallDialog(
          callerName: d['fromName'] ?? 'Cousin',
          callerPhoto: d['fromPhoto'] ?? '',
          callType: type,
          onAccept: () async {
            await _db.ref('calls/$uid/$key/status').set('accepted');
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => AgoraCallScreen(
                channel: d['channel'] ?? '', calleeName: d['fromName'] ?? 'Cousin',
                calleePhoto: d['fromPhoto'] ?? '', callType: type,
                isCaller: false, callKey: key, calleeUid: uid)));
          },
          onDecline: () => _db.ref('calls/$uid/$key/status').set('declined')));
      _showing = false;
    });
  }
  @override void dispose() { _sub?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => widget.child;
}

class IncomingCallDialog extends StatefulWidget {
  final String callerName, callerPhoto;
  final CallType callType;
  final VoidCallback onAccept, onDecline;
  const IncomingCallDialog({super.key, required this.callerName,
    required this.callerPhoto, required this.callType,
    required this.onAccept, required this.onDecline});
  @override State<IncomingCallDialog> createState() => _ICDState();
}
class _ICDState extends State<IncomingCallDialog> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _pulse;
  Timer? _vib;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulse = Tween<double>(begin:1.0,end:1.1).animate(CurvedAnimation(parent:_ac,curve:Curves.easeInOut));
    HapticFeedback.heavyImpact();
    _vib = Timer.periodic(const Duration(seconds:2),(_){if(mounted)HapticFeedback.mediumImpact();});
  }
  @override void dispose() { _ac.dispose(); _vib?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent, elevation: 0,
    child: Container(padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[Color(0xFF1a1a3e),Color(0xFF0a0a1a)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color:Colors.white.withOpacity(0.1))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.callType==CallType.video?'📹 Incoming Video Call':'📞 Incoming Voice Call',
          style: const TextStyle(color:Colors.white60,fontSize:13,fontWeight:FontWeight.w700)),
        const SizedBox(height:24),
        AnimatedBuilder(animation:_pulse, builder:(_,child)=>Transform.scale(scale:_pulse.value,child:child),
          child: Container(width:88,height:88,decoration:BoxDecoration(shape:BoxShape.circle,
            gradient:AppTheme.mainGradient,border:Border.all(color:Colors.white,width:3),
            boxShadow:[BoxShadow(color:AppTheme.primary.withOpacity(0.5),blurRadius:20)]),
            child: widget.callerPhoto.isNotEmpty
              ? ClipOval(child:Image.network(widget.callerPhoto,fit:BoxFit.cover))
              : Center(child:Text(widget.callerName[0].toUpperCase(),
                  style:const TextStyle(color:Colors.white,fontSize:36,fontWeight:FontWeight.w900))))),
        const SizedBox(height:16),
        Text(widget.callerName,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        Text(widget.callType==CallType.video?'Wants to video call':'Wants to voice call',
          style:const TextStyle(color:Colors.white54,fontSize:13)),
        const SizedBox(height:32),
        Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          _callBtn(Icons.call_end_rounded,'Decline',Colors.red,(){Navigator.pop(context);widget.onDecline();}),
          _callBtn(widget.callType==CallType.video?Icons.videocam_rounded:Icons.call_rounded,
            'Accept',Colors.green,(){Navigator.pop(context);widget.onAccept();}),
        ]),
      ])));
  Widget _callBtn(IconData icon,String lbl,Color col,VoidCallback fn)=>
    GestureDetector(onTap:fn,child:Column(children:[
      Container(width:64,height:64,decoration:BoxDecoration(color:col,shape:BoxShape.circle,
        boxShadow:[BoxShadow(color:col.withOpacity(0.45),blurRadius:14)]),
        child:Icon(icon,color:Colors.white,size:28)),
      const SizedBox(height:8),
      Text(lbl,style:const TextStyle(color:Colors.white60,fontSize:12,fontWeight:FontWeight.w700)),
    ]));
}

class AgoraCallScreen extends StatefulWidget {
  final String channel, calleeName, calleePhoto;
  final CallType callType;
  final bool isCaller;
  final String? callKey, calleeUid;
  const AgoraCallScreen({super.key, required this.channel, required this.calleeName,
    required this.calleePhoto, required this.callType, required this.isCaller,
    this.callKey, this.calleeUid});
  @override State<AgoraCallScreen> createState() => _AgoraCallState();
}
class _AgoraCallState extends State<AgoraCallScreen> {
  RtcEngine? _engine;
  bool _joined=false,_muted=false,_camOff=false,_speaker=true;
  int? _remoteUid;
  int _secs=0;
  Timer? _timer;
  final _db=FirebaseDatabase.instance;
  bool _loading=true;
  String _errMsg='';

  @override void initState(){super.initState();_init();}

  Future<void> _init() async {
    final perms=widget.callType==CallType.video
      ?[Permission.camera,Permission.microphone]:[Permission.microphone];
    final res=await perms.request();
    if(res.values.any((s)=>s.isDenied||s.isPermanentlyDenied)){
      setState((){_loading=false;_errMsg='Permission denied!\\nSettings থেকে Microphone${widget.callType==CallType.video?" & Camera":""} allow করো।';});
      return;
    }
    try {
      _engine=createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId:kAgoraAppId,
        channelProfile:ChannelProfileType.channelProfileCommunication));
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess:(_,__){if(mounted)setState((){_joined=true;_loading=false;});},
        onUserJoined:(_,uid,__){if(mounted)setState(()=>_remoteUid=uid);_startTimer();},
        onUserOffline:(_,uid,__){if(mounted)setState(()=>_remoteUid=null);Future.delayed(const Duration(seconds:2),_endCall);},
        onError:(err,msg){if(mounted)setState((){_loading=false;_errMsg='Error: $msg\n\nAgora Console এ App Certificate DISABLE করো!';});}));
      if(widget.callType==CallType.video){await _engine!.enableVideo();await _engine!.startPreview();}
      await _engine!.enableAudio();
      await _engine!.setEnableSpeakerphone(true);
      await _engine!.joinChannel(
        token:'', channelId:widget.channel, uid:0,
        options:ChannelMediaOptions(
          clientRoleType:ClientRoleType.clientRoleBroadcaster,
          channelProfile:ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack:true,
          publishCameraTrack:widget.callType==CallType.video,
          autoSubscribeAudio:true,
          autoSubscribeVideo:widget.callType==CallType.video));
    } catch(e){
      if(mounted)setState((){_loading=false;_errMsg='Failed: $e\n\nAgora Console → Project → App Certificate → OFF করো';});
    }
  }

  void _startTimer(){_timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_secs++);});}
  String get _dur{final m=_secs~/60,s=_secs%60;return'${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';}

  Future<void> _endCall() async {
    _timer?.cancel();
    await _engine?.leaveChannel();await _engine?.release();
    if(widget.callKey!=null&&widget.calleeUid!=null)
      await _db.ref('calls/${widget.calleeUid}/${widget.callKey}/status').set('ended');
    if(mounted)Navigator.pop(context);
  }

  @override void dispose(){_timer?.cancel();_engine?.leaveChannel();_engine?.release();super.dispose();}

  @override
  Widget build(BuildContext context){
    return PopScope(canPop:false,child:Scaffold(
      backgroundColor:const Color(0xFF0a0a1a),
      body:Stack(children:[
        if(widget.callType==CallType.video&&_remoteUid!=null&&_engine!=null)
          Positioned.fill(child:AgoraVideoView(controller:VideoViewController.remote(
            rtcEngine:_engine!,canvas:VideoCanvas(uid:_remoteUid),
            connection:RtcConnection(channelId:widget.channel))))
        else
          Positioned.fill(child:Container(decoration:const BoxDecoration(
            gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
              colors:[Color(0xFF1a0a2e),Color(0xFF050510)])))),

        if(widget.callType==CallType.video&&_joined&&_engine!=null&&!_camOff)
          Positioned(top:60,right:16,width:108,height:152,
            child:ClipRRect(borderRadius:BorderRadius.circular(12),
              child:AgoraVideoView(controller:VideoViewController(
                rtcEngine:_engine!,canvas:const VideoCanvas(uid:0))))),

        SafeArea(child:Column(children:[
          const SizedBox(height:32),
          if(widget.callType==CallType.voice||_remoteUid==null)
            Container(width:96,height:96,decoration:BoxDecoration(shape:BoxShape.circle,
              gradient:AppTheme.mainGradient,border:Border.all(color:Colors.white.withOpacity(0.3),width:3)),
              child:widget.calleePhoto.isNotEmpty
                ?ClipOval(child:Image.network(widget.calleePhoto,fit:BoxFit.cover))
                :Center(child:Text(widget.calleeName[0].toUpperCase(),
                    style:const TextStyle(color:Colors.white,fontSize:40,fontWeight:FontWeight.w900)))),
          const SizedBox(height:16),
          Text(widget.calleeName,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          if(_loading)const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white60)),
            SizedBox(width:8),Text('Connecting...',style:TextStyle(color:Colors.white60,fontSize:14))])
          else if(_errMsg.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(horizontal:24),
            child:Text(_errMsg,textAlign:TextAlign.center,style:const TextStyle(color:Colors.redAccent,fontSize:12)))
          else Text(_remoteUid!=null?_dur:(_joined?'Ringing...':'Connecting...'),
            style:const TextStyle(color:Colors.white60,fontSize:16)),
        ])),

        if(_errMsg.isNotEmpty)Positioned(bottom:120,left:16,right:16,
          child:OutlinedButton(onPressed:(){setState((){_errMsg='';_loading=true;});_init();},
            style:OutlinedButton.styleFrom(side:const BorderSide(color:Colors.white30),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(100))),
            child:const Text('Retry',style:TextStyle(color:Colors.white70)))),

        Positioned(bottom:0,left:0,right:0,child:SafeArea(child:Container(
          padding:const EdgeInsets.fromLTRB(16,16,16,24),
          decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.bottomCenter,end:Alignment.topCenter,
            colors:[Colors.black.withOpacity(0.85),Colors.transparent])),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
            _btn(icon:_muted?Icons.mic_off_rounded:Icons.mic_rounded,lbl:_muted?'Unmute':'Mute',
              bg:_muted?Colors.red.withOpacity(0.8):Colors.white.withOpacity(0.15),
              fn:()async{setState(()=>_muted=!_muted);await _engine?.muteLocalAudioStream(_muted);}),
            if(widget.callType==CallType.video)
              _btn(icon:_camOff?Icons.videocam_off_rounded:Icons.videocam_rounded,lbl:_camOff?'Cam Off':'Camera',
                bg:_camOff?Colors.red.withOpacity(0.8):Colors.white.withOpacity(0.15),
                fn:()async{setState(()=>_camOff=!_camOff);await _engine?.muteLocalVideoStream(_camOff);}),
            GestureDetector(onTap:_endCall,child:Column(children:[
              Container(width:64,height:64,decoration:BoxDecoration(color:Colors.red,shape:BoxShape.circle,
                boxShadow:[BoxShadow(color:Colors.red.withOpacity(0.5),blurRadius:16)]),
                child:const Icon(Icons.call_end_rounded,color:Colors.white,size:30)),
              const SizedBox(height:6),
              const Text('End',style:TextStyle(color:Colors.white60,fontSize:11,fontWeight:FontWeight.w700)),
            ])),
            _btn(icon:_speaker?Icons.volume_up_rounded:Icons.hearing_rounded,lbl:_speaker?'Speaker':'Ear',
              bg:_speaker?Colors.blue.withOpacity(0.5):Colors.white.withOpacity(0.15),
              fn:()async{setState(()=>_speaker=!_speaker);await _engine?.setEnableSpeakerphone(_speaker);}),
            if(widget.callType==CallType.video)
              _btn(icon:Icons.flip_camera_ios_rounded,lbl:'Flip',bg:Colors.white.withOpacity(0.15),
                fn:()=>_engine?.switchCamera())
            else
              _btn(icon:Icons.dialpad_rounded,lbl:'Keypad',bg:Colors.white.withOpacity(0.15),fn:(){}),
          ])))),
      ])));
  }

  Widget _btn({required IconData icon,required String lbl,required Color bg,required VoidCallback fn})=>
    GestureDetector(onTap:fn,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:52,height:52,decoration:BoxDecoration(color:bg,shape:BoxShape.circle),
        child:Icon(icon,color:Colors.white,size:22)),
      const SizedBox(height:5),
      Text(lbl,style:const TextStyle(color:Colors.white60,fontSize:10,fontWeight:FontWeight.w700)),
    ]));
}

class CallStarter {
  static final _db=FirebaseDatabase.instance;
  static Future<void> call({required BuildContext context,required String toUid,
    required String toName,required String toPhoto,required CallType type}) async {
    final myUid=AuthService().currentUid??'';
    final p=await AuthService().getProfile(myUid);
    final myName=p?['nickname']??p?['name']??'Cousin';
    final myPhoto=p?['photoUrl']??'';
    final channel='ch_${myUid.substring(0,6)}_${DateTime.now().millisecondsSinceEpoch}';
    final ref=_db.ref('calls/$toUid').push();
    await ref.set({'fromUid':myUid,'fromName':myName,'fromPhoto':myPhoto,
      'type':type==CallType.video?'video':'voice','channel':channel,
      'status':'ringing','timestamp':ServerValue.timestamp});
    final ts=await _db.ref('users/$toUid/fcmToken').get();
    if(ts.exists)await _db.ref('notifications').push().set({'toToken':ts.value,
      'title':type==CallType.video?'📹 Video Call':'📞 Voice Call',
      'body':'$myName is calling you...','sent':false,'timestamp':ServerValue.timestamp});
    if(context.mounted)Navigator.push(context,MaterialPageRoute(
      builder:(_)=>AgoraCallScreen(channel:channel,calleeName:toName,calleePhoto:toPhoto,
        callType:type,isCaller:true,callKey:ref.key,calleeUid:toUid)));
  }
}
