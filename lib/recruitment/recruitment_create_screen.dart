import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/sport_icons.dart';
import '../routing/app_routes.dart';
import 'recruitment.dart';
import 'recruitment_ai.dart';
import 'sport_fields.dart';
import 'place_picker_screen.dart';
import 'recruitment_location.dart';

class RecruitmentCreateScreen extends StatefulWidget {
  const RecruitmentCreateScreen({super.key, this.ai, required this.initialSport});
  final RecruitmentAi? ai;
  final String initialSport;
  @override
  State<RecruitmentCreateScreen> createState() => _RecruitmentCreateScreenState();
}

class _RecruitmentCreateScreenState extends State<RecruitmentCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _place = TextEditingController();
  RecruitmentLocation? _location;
  final _min = TextEditingController(text:'2');
  final _max = TextEditingController(text:'6');
  final _details = TextEditingController();
  final _fields = <String, Set<String>>{};
  late final RecruitmentAi _ai = widget.ai ?? RecruitmentAi();
  late final String _sport = widget.initialSport;
  String _intensity = '보통';
  DateTime _date = DateUtils.dateOnly(DateTime.now().add(const Duration(days:1)));
  TimeOfDay _start = const TimeOfDay(hour:19,minute:0);
  TimeOfDay _end = const TimeOfDay(hour:20,minute:0);
  bool _merge = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _place.dispose(); _min.dispose(); _max.dispose(); _details.dispose();
    if (widget.ai == null) _ai.close();
    super.dispose();
  }
  DateTime _at(TimeOfDay t) => DateTime(_date.year,_date.month,_date.day,t.hour,t.minute);
  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(context:context,initialDate:_date.isBefore(today)?today:_date,firstDate:today,lastDate:today.add(const Duration(days:365)));
    if (mounted && picked != null) setState(()=>_date=picked);
  }
  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context:context, initialTime:start?_start:_end);
    if (mounted && picked != null) setState(() { if(start) { _start=picked; } else { _end=picked; } });
  }
  Future<void> _pickPlace() async {
    FocusScope.of(context).unfocus();
    final chosen = await Navigator.of(context).push<RecruitmentLocation>(MaterialPageRoute(
      builder: (_) => PlacePickerScreen(initial: _location, initialName: _place.text.trim())));
    if (!mounted || chosen == null) return;
    setState(() { _location = chosen; _place.text = chosen.name; });
  }
  Future<void> _generate({required bool manual}) async {
    if (_busy || !_form.currentState!.validate()) return;
    final owner = context.read<AppState>().loginId;
    if (owner == null) return;
    final minPeople = int.tryParse(_min.text.trim());
    final maxPeople = int.tryParse(_max.text.trim());
    if (minPeople == null || maxPeople == null) {
      setState(() => _error = '모집 인원을 숫자로 입력해주세요.');
      return;
    }
    final input = RecruitmentInput(sport:_sport,start:_at(_start),end:_at(_end),place:_place.text.trim(),
      minPeople:minPeople,maxPeople:maxPeople,intensity:_intensity,
      fields:{for(final entry in _fields.entries) if(entry.value.isNotEmpty) entry.key:entry.value.join(', ')},
      details:_details.text.trim(),allowMerge:_merge,location:_location);
    final issue = input.validate();
    if(issue != null) {setState(()=>_error=issue);return;}
    FocusScope.of(context).unfocus();
    setState((){_busy=true;_error=null;});
    RecruitmentDraft? draft;
    try { draft = manual ? RecruitmentDraft.manual(input) : await _ai.generate(input); }
    on RecruitmentAiFailure catch(e) { if(mounted) setState(()=>_error=e.message); }
    finally { if(mounted) setState(()=>_busy=false); }
    if(!mounted || draft == null || context.read<AppState>().loginId != owner) return;
    final result = draft;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>RecruitmentPreviewScreen(input:input,draft:result,owner:owner,manual:manual)));
    if(!mounted || saved != true) return;
    if(context.canPop()) {context.pop(true);} else {context.go('/community/${AppRoutes.sportId(_sport)}');}
  }
  Widget _label(String label) => Padding(padding:const EdgeInsets.only(top:18,bottom:8),child:Text(label,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)));
  Widget _number(TextEditingController c,String label) => TextFormField(controller:c,enabled:!_busy,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'명'),validator:(v){final n=int.tryParse(v?.trim()??'');return n==null||n<1||n>100?'1~100명':null;});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = sportFields[_sport] ?? const <String,List<String>>{};
    return Scaffold(appBar:AppBar(title:const Text('모집글 작성')),body:SafeArea(child:Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,8,18,28),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('함께 운동할 사람을 모집해요',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      Text('조건을 선택하면 AI가 모집글 초안을 작성해요.',style:TextStyle(color:scheme.onSurfaceVariant)),
      _label('운동 종목'),
      Chip(label: Text(_sport), avatar: Icon(sportIcon(_sport), size: 18)),
      _label('운동 날짜 및 시간'),
      OutlinedButton.icon(onPressed:_busy?null:_pickDate,icon:const Icon(Icons.calendar_today_outlined),label:Text('${_date.year}년 ${_date.month}월 ${_date.day}일')),
      Row(children:[Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_pickTime(true),child:Text('시작 ${_start.format(context)}'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_pickTime(false),child:Text('종료 ${_end.format(context)}')))]),
      _label('운동 장소'),TextFormField(key: const Key('recruitment-place'),controller:_place,enabled:!_busy,maxLength:120,onChanged: (_) { if (_location != null) setState(() => _location = null); },decoration:const InputDecoration(hintText:'예: 중앙대학교 운동장',prefixIcon:Icon(Icons.place_outlined)),validator:(v)=>v==null||v.trim().isEmpty?'장소를 입력해주세요.':null),
      OutlinedButton.icon(key: const Key('recruitment-pick-map'), onPressed: _busy ? null : _pickPlace, icon: const Icon(Icons.map_outlined), label: Text(_location == null ? '지도에서 장소 선택 / 주소 검색' : '지도 위치 변경')),
      if (_location != null) Text(_location!.address.isEmpty ? '지도 위치 지정 완료 (${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)})' : _location!.address),
      _label('모집 인원'),Row(children:[Expanded(child:_number(_min,'최소 인원')),const SizedBox(width:12),Expanded(child:_number(_max,'최대 인원'))]),
      _label('운동 강도'),Wrap(spacing:8,children:[for(final level in ['가볍게','보통','강하게']) ChoiceChip(label:Text(level),selected:_intensity==level,onSelected:_busy?null:(_)=>setState(()=>_intensity=level))]),
      for(final entry in extras.entries)...[
        _label('${entry.key} (선택)'),
        Wrap(spacing:8,runSpacing:6,children:[for(final option in entry.value) FilterChip(label:Text(option),selected:_fields[entry.key]?.contains(option)??false,onSelected:_busy?null:(selected)=>setState((){final values=_fields.putIfAbsent(entry.key,()=> <String>{});if(!selected){values.remove(option);}else if(entry.key=='모집 포지션'&&option!='무관'){values.remove('무관');values.add(option);}else{values..clear()..add(option);}}))]),
      ],
      _label('추가 세부사항 및 규칙'),TextFormField(controller:_details,enabled:!_busy,maxLength:1000,minLines:3,maxLines:5,decoration:const InputDecoration(hintText:'준비물, 경기 규칙, 기타 요구사항을 자유롭게 입력해주세요.')),
      const Divider(),CheckboxListTile(value:_merge,controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero,onChanged:_busy?null:(value)=>setState(()=>_merge=value??false),title:const Text('다른 모임과의 병합을 허용합니다.'),subtitle:const Text('인원이 부족할 때 병합 추천을 받을 수 있어요. 실제 병합은 별도 동의가 필요해요.')),
      if(_error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(_error!,style:TextStyle(color:scheme.error))),
      const SizedBox(height:12),FilledButton.icon(onPressed:_busy?null:()=>_generate(manual:false),icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.auto_awesome),label:Text(_busy?'AI 모집글 생성 중…':'AI 모집글 생성')),
      TextButton(key: const Key('recruitment-manual'),onPressed:_busy?null:()=>_generate(manual:true),child:const Text('AI 없이 직접 작성')),
    ])))));
  }
}

class RecruitmentPreviewScreen extends StatefulWidget {
  const RecruitmentPreviewScreen({super.key,required this.input,required this.draft,required this.owner,required this.manual});
  final RecruitmentInput input;
  final RecruitmentDraft draft;
  final String owner;
  final bool manual;
  @override
  State<RecruitmentPreviewScreen> createState()=>_RecruitmentPreviewScreenState();
}
class _RecruitmentPreviewScreenState extends State<RecruitmentPreviewScreen> {
  final _form=GlobalKey<FormState>();
  late final _title=TextEditingController(text:widget.draft.title);
  late final _body=TextEditingController(text:widget.draft.body);
  late final _conditions=widget.draft.conditions.toSet();
  bool _saving=false;
  String? _error;
  @override
  void dispose(){_title.dispose();_body.dispose();super.dispose();}
  Future<void> _save() async {
    if(_saving||!_form.currentState!.validate())return;
    if(context.read<AppState>().loginId!=widget.owner)return;
    final issue=widget.input.validate();
    if(issue!=null){setState(()=>_error=issue);return;}
    setState((){_saving=true;_error=null;});
    try{
      final vm = context.read<AppState>().members;
      final ok = await vm.publishRecruitment(widget.input,
        RecruitmentDraft(_title.text.trim(), _body.text.trim(), conditions: _conditions.toList()), ownerId: widget.owner);
      if (!mounted) return;
      if (ok) { Navigator.of(context).pop(true); }
      else { setState(() => _error = vm.error ?? '저장할 수 없어요. 다시 시도해주세요.'); }
    }catch(_){if(mounted)setState(()=>_error='기기에 저장하지 못했어요. 다시 시도해주세요.');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  @override
  Widget build(BuildContext context){final i=widget.input;return Scaffold(appBar:AppBar(title:const Text('모집글 미리보기')),body:SafeArea(child:Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(widget.manual?'직접 작성 초안':'AI 생성 초안',style:Theme.of(context).textTheme.titleLarge),
    const Text('내용을 확인하고 수정해주세요. 매칭에 사용하는 조건은 이전 화면의 입력값이에요.'),
    const SizedBox(height:16),TextFormField(controller:_title,enabled:!_saving,maxLength:60,decoration:const InputDecoration(labelText:'제목'),validator:(v)=>v==null||v.trim().isEmpty?'제목을 입력해주세요.':null),
    const SizedBox(height:12),TextFormField(controller:_body,enabled:!_saving,maxLength:1000,minLines:6,maxLines:12,decoration:const InputDecoration(labelText:'본문'),validator:(v)=>v==null||v.trim().isEmpty?'본문을 입력해주세요.':null),
    const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(12),child:Text(['${i.sport} · ${i.schedule}', '${i.place} · ${i.minPeople}~${i.maxPeople}명', if (i.location?.address.isNotEmpty ?? false) i.location!.address, '강도: ${i.intensity}', ...i.fields.entries.map((e) => '${e.key}: ${e.value}'), '병합 허용: ${i.allowMerge ? '예' : '아니오'}'].join('\n')))),
    if(widget.draft.conditions.isNotEmpty)...[const Text('AI가 추출한 추가 조건 (확인 후 저장)'),for(final condition in widget.draft.conditions.toSet()) CheckboxListTile(value:_conditions.contains(condition),title:Text(condition),onChanged:_saving?null:(v)=>setState(()=>v==true?_conditions.add(condition):_conditions.remove(condition)))],
    if(_error!=null)Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    const SizedBox(height:12),FilledButton(key: const Key('recruitment-publish'),onPressed:_saving?null:_save,child:Text(_saving?'저장 중…':'모집글 등록 (내 기기)')),
    const Text('현재는 내 기기에만 저장됩니다. 같은 기기에서 로그인한 회원에게 표시되며, 다른 기기와 공유되지 않습니다.'),
  ])))));}
}
