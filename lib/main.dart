import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(MaterialApp(home: VideoCall()));

class VideoCall extends StatefulWidget { @override _VideoCallState createState() => _VideoCallState(); }

class _VideoCallState extends State<VideoCall> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _remoteIdController = TextEditingController();
  String? myId;
  WebSocketChannel? channel;
  RTCPeerConnection? pc;
  MediaStream? localStream;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    localStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    _localRenderer.srcObject = localStream;
    
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:3000'));
    channel!.stream.listen((msg) async {
      var data = jsonDecode(msg);
      if(data['type']=='id'){ setState(()=>myId=data['id']); return; }
      if(data['type']=='offer'){
        await createPeer(false);
        await pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
        var answer = await pc!.createAnswer();
        await pc!.setLocalDescription(answer);
        channel!.sink.add(jsonEncode({'to':data['from'], 'type':answer.type, 'sdp':answer.sdp}));
      }
      if(data['type']=='answer'){
        await pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
      }
      if(data['type']=='candidate'){
        await pc!.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
      }
    });
  }

  createPeer(bool isCaller) async {
    pc = await createPeerConnection({'iceServers':[{'urls':'stun:stun.l.google.com:19302'}]});
    localStream!.getTracks().forEach((t)=>pc!.addTrack(t, localStream!));
    pc!.onTrack = (e){ _remoteRenderer.srcObject = e.streams[0]; setState((){}); };
    pc!.onIceCandidate = (c){ if(c.candidate!=null) channel!.sink.add(jsonEncode({'to':_remoteIdController.text, 'type':'candidate','candidate':c.candidate,'sdpMid':c.sdpMid,'sdpMLineIndex':c.sdpMLineIndex})); };
  }

  call() async {
    await createPeer(true);
    var offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);
    channel!.sink.add(jsonEncode({'to':_remoteIdController.text, 'type':offer.type, 'sdp':offer.sdp}));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('My ID: $myId')),
      body: Column(children:[
        Expanded(child: Row(children:[Expanded(child: RTCVideoView(_localRenderer, mirror:true)), Expanded(child: RTCVideoView(_remoteRenderer)) ])),
        Padding(padding: EdgeInsets.all(8), child: TextField(controller: _remoteIdController, decoration: InputDecoration(labelText: 'Enter Friend ID', border: OutlineInputBorder()))),
        ElevatedButton(onPressed: call, child: Text('CALL')),
      ]));
  }
}