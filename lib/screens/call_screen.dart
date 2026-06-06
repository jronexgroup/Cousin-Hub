import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';

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
              builder: (_) => CallScreen(
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

class CallScreen extends StatefulWidget {
  final String channel, calleeName, calleePhoto;
  final CallType callType;
  final bool isCaller;
  final String? callKey, calleeUid;
  const CallScreen({super.key, required this.channel, required this.calleeName,
    required this.calleePhoto, required this.callType, required this.isCaller,
    this.callKey, this.calleeUid});
  @override State<CallScreen> createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> {
  final _db=FirebaseDatabase.instance;

  @override void initState(){super.initState();_init();}

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds:2));
    _endCall();
  }

  Future<void> _endCall() async {
    if(widget.callKey!=null&&widget.calleeUid!=null)
      await _db.ref('calls/${widget.calleeUid}/${widget.callKey}/status').set('ended');
    if(mounted)Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context){
    return PopScope(canPop:false,child:Scaffold(
      backgroundColor:const Color(0xFF0a0a1a),
      body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:96,height:96,decoration:BoxDecoration(shape:BoxShape.circle,
          gradient:AppTheme.mainGradient,border:Border.all(color:Colors.white.withOpacity(0.3),width:3)),
          child:widget.calleePhoto.isNotEmpty
            ?ClipOval(child:Image.network(widget.calleePhoto,fit:BoxFit.cover))
            :Center(child:Text(widget.calleeName[0].toUpperCase(),
                style:const TextStyle(color:Colors.white,fontSize:40,fontWeight:FontWeight.w900)))),
        const SizedBox(height:16),
        Text(widget.calleeName,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
        const SizedBox(height:12),
        const Text('🔧 Voice/Video calls coming soon\nwith WebRTC',textAlign:TextAlign.center,
          style:TextStyle(color:Colors.white54,fontSize:14)),
        const SizedBox(height:32),
        GestureDetector(onTap:_endCall,child:Column(children:[
          Container(width:64,height:64,decoration:BoxDecoration(color:Colors.red,shape:BoxShape.circle,
            boxShadow:[BoxShadow(color:Colors.red.withOpacity(0.5),blurRadius:16)]),
            child:const Icon(Icons.call_end_rounded,color:Colors.white,size:30)),
          const SizedBox(height:6),
          const Text('End',style:TextStyle(color:Colors.white60,fontSize:11,fontWeight:FontWeight.w700)),
        ])),
      ]))));
  }
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
      builder:(_)=>CallScreen(channel:channel,calleeName:toName,calleePhoto:toPhoto,
        callType:type,isCaller:true,callKey:ref.key,calleeUid:toUid)));
  }
}
