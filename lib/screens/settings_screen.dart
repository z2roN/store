import 'package:flutter/material.dart';
import '../api.dart';
import '../main.dart';
import 'common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final inC = TextEditingController(text: Api.i.internalAddr);
  final exC = TextEditingController(text: Api.i.externalAddr);
  final store = TextEditingController(), biz = TextEditingController(), addr = TextEditingController(), phone = TextEditingController(), foot = TextEditingController();
  List users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => guard(context, () async {
        final s = await Api.i.get('/api/settings') as Map;
        store.text = s['storeName'] ?? '';
        biz.text = s['bizNo'] ?? '';
        addr.text = s['address'] ?? '';
        phone.text = s['phone'] ?? '';
        foot.text = s['receiptFooter'] ?? '';
        if (Api.i.isAdmin) users = await Api.i.get('/api/users');
        if (mounted) setState(() {});
      });

  Future<void> _userDialog([Map? u]) async {
    final ln = TextEditingController(text: '${u?['LoginName'] ?? ''}');
    final dn = TextEditingController(text: '${u?['DisplayName'] ?? ''}');
    final pin = TextEditingController();
    String role = '${u?['Role'] ?? 'staff'}';
    bool active = u?['Active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(u == null ? '직원 추가' : '직원 수정'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (u == null) field(ln, '아이디'),
            field(dn, '이름'),
            field(pin, u == null ? '비밀번호' : '새 비밀번호 (바꿀 때만)'),
            DropdownButton<String>(value: role, items: const [DropdownMenuItem(value: 'staff', child: Text('직원')), DropdownMenuItem(value: 'admin', child: Text('관리자'))], onChanged: (v) => set(() => role = v!)),
            if (u != null) SwitchListTile(title: const Text('사용'), value: active, onChanged: (v) => set(() => active = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(
              onPressed: () => guard(ctx, () async {
                await Api.i.post('/api/users', {'id': u?['Id'] ?? 0, 'loginName': ln.text.trim(), 'pin': pin.text, 'displayName': dn.text.trim(), 'role': role, 'active': active});
                if (ctx.mounted) Navigator.pop(ctx, true);
              }),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('서버 연결', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        field(inC, '서버 주소 (매장 내부) 예) 192.168.0.10:5080'),
        field(exC, '서버 주소 (외부, 선택)'),
        Row(children: [
          FilledButton(
            onPressed: () => guard(context, () async {
              await Api.i.saveAddrs(inC.text, exC.text);
              final r = await Api.i.connect();
              if (mounted) toast(context, '연결됨: ${r['store']} (${Api.i.onExternal ? '외부' : '내부'} 주소)');
            }),
            child: const Text('저장 후 연결 확인'),
          ),
          const SizedBox(width: 12),
          Text('현재: ${Api.i.activeAddr.isEmpty ? '-' : Api.i.activeAddr}'),
        ]),
        const Divider(height: 32),
        Text('매장 정보 (영수증에 인쇄)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        field(store, '상호'),
        field(biz, '사업자번호'),
        field(addr, '주소'),
        field(phone, '전화번호'),
        field(foot, '영수증 하단 문구'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: Api.i.isAdmin
                ? () => guard(context, () async {
                      await Api.i.post('/api/settings', {'storeName': store.text, 'bizNo': biz.text, 'address': addr.text, 'phone': phone.text, 'receiptFooter': foot.text});
                      if (mounted) toast(context, '저장되었습니다');
                    })
                : null,
            child: Text(Api.i.isAdmin ? '매장 정보 저장' : '매장 정보 저장 (관리자만)'),
          ),
        ),
        if (Api.i.isAdmin) ...[
          const Divider(height: 32),
          Row(children: [Text('직원 계정', style: Theme.of(context).textTheme.titleMedium), const Spacer(), TextButton.icon(onPressed: () => _userDialog(), icon: const Icon(Icons.add), label: const Text('추가'))]),
          for (final u in users) ListTile(dense: true, title: Text('${u['DisplayName']} (${u['LoginName']})'), subtitle: Text('${u['Role'] == 'admin' ? '관리자' : '직원'}${u['Active'] == false ? '  · 사용 안 함' : ''}'), onTap: () => _userDialog(u)),
        ],
        const Divider(height: 32),
        Text('z2roN-Store v$kAppVersion'),
      ]);
}
