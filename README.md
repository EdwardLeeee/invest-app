# 個股研究室 iPhone app（invest-app）

The iPhone shell for the equity research room at <https://invest.oraclelee.com>: a
[Capacitor](https://capacitorjs.com) app that bundles the site's web build and reads the
reports from the public site over HTTPS. Distributed to its owner through TestFlight only;
it is not on the App Store.

## 這個 repo 裡有什麼

- **app 外殼**：Capacitor 設定與 Xcode 專案（只支援 iPhone、iOS 15 以上）。
- **網頁 build**：從研究室網站的前端建出來的靜態檔，與 invest.oraclelee.com 上公開提供的檔案相同。
  網站與研究的原始碼在另一個私有 repo，不在這裡。
- **CI**：在 GitHub 的 macOS runner 建置、簽章並上傳到 TestFlight；TestFlight 版本 90 天過期前自動重建。

這裡**沒有**報告資料（app 執行時才從網站讀取），也沒有任何簽章檔或金鑰（只存在開發機與 GitHub secrets）。

## 狀態

建置中：網頁的新介面還在設計，`web/` 目前只有一張佔位頁，app 圖示也是佔位圖（標著「暫代」）。
CI 流程是草稿（`.github/workflow-drafts/`，GitHub 不會執行），等新前端完成並匯入後才啟用。

## 文件

- [蘋果帳號設定](docs/apple-setup.md)：帳號持有人在 Apple 網站上要做的步驟。
- [建置、簽章與發布](docs/release.md)：換網頁、CI、簽章素材、一年一次的到期。

## 授權

程式碼採 [PolyForm Noncommercial 1.0.0](LICENSE)：允許非商業用途。報告內容是作者的個人研究，不構成投資建議。
