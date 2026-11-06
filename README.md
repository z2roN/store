# z2roN-Store (매장 관리 프로그램) v0.1.0 — 1단계

- `server/` : 서버(C#/.NET 8). MDB(Jet 4.0)를 소유하고 HTTP API 제공. 32비트 빌드(Windows 내장 Jet 사용).
- `lib/` : Flutter 앱(Windows + Android). 서버 주소(내부/외부) 설정, 판매(바코드), 상품, 재고, 고객, 내역, 영수증.
- `.github/workflows/build.yml` : GitHub Actions 로 서버/윈도우/안드로이드 빌드.

## 빌드
저장소에 올린 뒤 Actions > "z2roN_Store 빌드" > Run workflow. Artifacts 3개(server / windows / android).

## 서버 실행
`z2roN_StoreServer.exe` 실행 → `data/store.mdb` 자동 생성, `server.json` 으로 포트/경로/백업 설정. 기본 계정 admin/1234.

## 로드맵
1단계(현재): 판매·상품·재고·고객·내역·영수증 / 2단계: 매입, 일·월 마감, 할인 판매 / 3단계: 견적서, 주문서 업로드 인식 / 4단계: 모바일 다듬기.
