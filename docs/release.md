# 建置、簽章與發布

## 架構

| 項目 | 值 |
|---|---|
| Bundle ID | `com.oraclelee.invest`（上傳第一個建置後永久不能改） |
| 名稱 | 個股研究室（手機桌面與 App Store Connect） |
| Capacitor | core／cli／ios 8.5.2，精確版本；`npm run check:capacitor` 檢查 |
| iOS | Swift Package Manager、最低 iOS 15、只支援 iPhone、只允許直向、Xcode 26 以上 |
| 網頁 | `web/`，由 `scripts/import-web.sh` 從研究室私有 repo 建置；`web/BUILD.json` 記來源 commit |
| 頁面 Origin | `capacitor://localhost`；後端 `INVEST_APP_ORIGINS` 只放行它，只開 GET |
| 版本號 | 顯示版本＝`package.json` 的 `version`；建置號＝上傳當下的 UTC 時間 `YYYYMMDDHHmm` |
| 發布 | 只走 TestFlight 內部測試（群組「本人」，自動發送），不上架 |

## 換網頁

```bash
scripts/import-web.sh            # 研究室 repo 的 origin/main；也可以給 commit 或 tag
git add web && git commit -m "Bundle the research room's web at <commit>"
```

腳本只接受已推上研究室 origin/main 的 commit。以下任何一項不成立就停：

- 建出來的程式有呼叫 `https://invest.oraclelee.com`；
- 沒有 source map；
- 沒有把任何已發布的報告打包進去。報告只能經 API 讀，打包進去會變成舊資料。

app 裡的網頁是建置當下凍結的。網站換新介面以後，要再匯入一次並發版，app 才會帶上。

## CI

三個 workflow 都在 `.github/workflows/`。

- `mobile.yml`：每個 PR 都跑。
  - Ubuntu：版本鎖定、`npm audit`、`web/` 的來源與 API 網址。
  - macOS：建置模擬器版，檢查 bundle id、版本、名稱、出口合規鍵、只支援 iPhone、只允許直向、網頁有打包；
    再建置一次不簽章的 Release 裝置版；跑**模擬器 smoke test**（必須通過）；附深淺色模擬器截圖。
- **模擬器 smoke test**（`scripts/ios-smoke.sh` 加 `.github/smoke/smoke.js`）：把檢查腳本注入模擬器建置的**副本**
  （簽章的 app 不會有它），在 iPhone 模擬器裡由 app 自己的 WebKit、以 `capacitor://localhost` 讀正式站的報告清單，
  點開第一份報告，等摘要頁出現；任何 fetch 失敗、HTTP 錯誤或 JS 錯誤都算失敗。這就是 CORS 檢查：Cloudflare 對
  GitHub runner（Ubuntu、macOS 都一樣）上的 curl 回 403 挑戰頁（`cf-mitigated: challenge`，2026-10-16 實測），
  但不擋 app 的 WebKit。結果在 run summary 與 artifact（console 全文與截圖）。
  發版時封存出來、要上傳的 app 會另外檢查網頁裡沒有 `[smoke]` 字樣，確認簽章的 app 沒帶到檢查腳本。
  - **和前端的耦合**：腳本用到研究室前端的 `a.rep`（首頁報告列）、`.pg-summary`（報告摘要頁）、`.pg-status`
    （狀態頁）與「沒有網路連線」字樣。前端改了這些名稱，smoke 會 FAIL（不會誤判通過）；重新匯入 `web/` 後
    smoke 若 FAIL，先看 console 是不是卡在找不到這些元素，再改 `.github/smoke/smoke.js`。
- `mobile-release.yml`：手動執行，或由 `mobile-refresh.yml` 呼叫。
  - `preflight`（Ubuntu）確認 `web/BUILD.json` 與 7 個簽章 secrets；`smoke`（macOS）跑模擬器 smoke test；兩者都過才封存並上傳。
  - 只有在 smoke test 因 app 以外的原因失敗（模擬器卡住、runner 故障），而且你自己確認過 app 讀得到正式站時，才勾
    `skip_smoke` 重跑。自己確認可以用 `curl -s -D - -o /dev/null -H 'Origin: capacitor://localhost' https://invest.oraclelee.com/api/reports`
    （GET；用 `-I` 會送 HEAD，API 回 405），看到 200 和 `access-control-allow-origin: capacitor://localhost`。
- `mobile-refresh.yml`：每週一 02:23 UTC 執行。
  - 用 `scripts/asc-latest-build.mjs` 查最新有效建置還剩幾天，少於 30 天才呼叫 `mobile-release.yml` 重建（同樣要先通過 smoke test）。
  - TestFlight 建置 90 天過期，所以最晚第 60 天左右會重建一次；某一週失敗，下一週會再試。
  - **保活**：公開 repo 60 天沒有活動，GitHub 會停用排程 workflow，而 workflow 自己的執行不算活動。
    所以同一個 workflow 每週也會看 main 最後一次 commit 是幾天前；超過 50 天就推一個空 commit。

## 簽章素材

- **放在哪裡**：開發機的 `~/.config/invest-mobile/ios/`（權限 700）。這些檔案不進任何 repo。
- **來源**：發布憑證與 API 金鑰是團隊共用的，和四子棋同一套，從外接硬碟的備份還原（`docs/apple-setup.md` 第 0 步）。
- **描述檔**：只有它是這個 app 專用的，名稱 `Invest App Store`。
- **核對**：`scripts/ios-signing.sh check <描述檔>` 會核對描述檔的名稱、bundle id，以及它是否綁了還原回來的那張憑證。
- **存進 GitHub**：`scripts/ios-signing.sh secrets <描述檔> <Team ID> <app 的 Apple ID>` 寫入下列 secrets，
  外加 repo 變數 `ASC_APP_ID`：
  - `IOS_DIST_CERT_P12_BASE64`
  - `IOS_DIST_CERT_P12_PASSWORD`
  - `IOS_PROFILE_BASE64`
  - `APPLE_TEAM_ID`
  - `ASC_API_KEY_ID`
  - `ASC_API_ISSUER_ID`
  - `ASC_API_KEY_P8_BASE64`

## 一年一次

- **發布憑證 2027-09-25 到期**：和四子棋同一張。到期前要重做憑證和兩個 app 的描述檔，再分別更新兩個 repo 的 secrets。
- **Apple Developer Program 會費**：每年一次。
