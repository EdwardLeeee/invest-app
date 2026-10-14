# 個股研究室 iPhone app：蘋果帳號設定（路線 A：沿用四子棋的簽章素材）

這份是給你（Apple 開發者帳號持有人）照著點的，大約 15 分鐘。路線 A 的意思是：發布憑證和 App Store
Connect API 金鑰都**沿用四子棋那一套**，所以不用新建憑證、也不用新建金鑰。你要做的是：

- 接上外接硬碟，讓 invest-app 還原簽章檔（第 0 步）；
- 在蘋果網站登記新 app 的身分、做一個描述檔、建立 app 與內部測試群組（第 1～5 步）；
- 抄兩個代碼給 invest-app（第 6～7 步）。

轉檔、存進 GitHub、上傳 app 都由 invest-app 處理。第 8 步（iPhone 上安裝）要等第一個版本上傳後才做。

**開始前**

- 用你加入 Apple Developer Program 的 Apple ID 登入（會要兩步驟驗證）。
- 網頁上方如果有「需要同意新版協議」的橫幅，先按進去同意，不然後面的按鈕會是灰的。
- 下載的檔案留在 `~/Downloads` 就好，不用搬。

## 0. 接上外接硬碟（還原簽章檔）

備份在外接硬碟的 `iOS金鑰/` 資料夾（2026-09-26 建立）。

1. 把外接硬碟接上這台電腦。invest-app 會用**唯讀**方式掛載，不會改到硬碟上的任何檔案。
2. 硬碟上的檔案權限屬於舊電腦的帳號，現在的帳號讀不到，所以複製這一步要你在一般終端機（Ctrl+Alt+T）
   執行 invest-app 給你的那一行 `sudo install …` 並輸入登入密碼。它只會把三個檔**複製**到
   `~/.config/invest-mobile/ios/`（只有你的帳號能讀），不會放進任何 repo：
   - `distribution.p12`、`p12-password.txt`（發布憑證與它的密碼）
   - `AuthKey_<Key ID>.p8`（API 金鑰）
3. Key ID 與 Issuer ID 不是秘密，invest-app 直接從硬碟上的 `說明.txt` 讀出來寫成 `asc.json`。
4. 發布憑證的到期日是 **2027-09-25**（說明.txt 記載；複製完 invest-app 會再從憑證本身核對）。
   第 2 步要用它挑對憑證。之後就可以拔掉硬碟。

## 1. 登記 app 的身分（App ID）

告訴蘋果「com.oraclelee.invest 這個 app 是我的」。

1. 開 https://developer.apple.com/account/resources/identifiers/list
2. 按「Identifiers」標題旁的藍色 **＋**。
3. 選 **App IDs** → **Continue** → 選 **App** → **Continue**。
4. **Description** 填 `Invest`（這一欄只收英文字母和空白）。
5. **Bundle ID** 選 **Explicit**，填 `com.oraclelee.invest`（一字不差；第一個版本上傳後就永遠不能改）。
6. 下面一長串 Capabilities **都不用勾** → **Continue** → **Register**。

## 2. 建立描述檔（Provisioning Profile）

把「新 app 的身分」和「四子棋那張發布憑證」綁在一起。

1. 開 https://developer.apple.com/account/resources/profiles/list
2. 按「Profiles」標題旁的 **＋**。
3. 在 **Distribution** 底下選 **App Store Connect** → **Continue**。
4. **App ID** 選 `Invest (com.oraclelee.invest)` → **Continue**。
5. 憑證清單裡勾 **Apple Distribution**、**到期日是 2027/09/25** 的那一張 → **Continue**。
   （如果清單只有一張，就是它。）
6. **Provisioning Profile Name** 一定要填 `Invest App Store`（大小寫、空白都要一樣，程式用這個名字找它）→ **Generate**。
7. 按 **Download**。檔案（類似 `Invest_App_Store.mobileprovision`）會存到 `~/Downloads`。

## 3. 在 App Store Connect 建立 app

只走 TestFlight 也要先建 app 紀錄。這一步才會知道名稱有沒有被別人用掉。

1. 開 https://appstoreconnect.apple.com/apps → 左上角 **＋** → **New App**。
2. **Platforms** 勾 **iOS**。
3. **Name** 填 `個股研究室`。如果出現「名稱已被使用」，**先停下來**告訴 invest-app，由你另取名字。
4. **Primary Language** 選 **Chinese (Traditional)**（繁體中文）。
5. **Bundle ID** 選 `Invest - com.oraclelee.invest`。
6. **SKU** 填 `invest-ios`（只給自己看的代號）。
7. **User Access** 選 **Full Access** → **Create**。

不用填商店描述、截圖、隱私權網址：這個 app 不上架。

## 4. 建立內部測試群組

讓每個新版本一上傳完成就自動推到你的 iPhone。

1. 在剛建好的 app 頁面，點上方的 **TestFlight** 分頁。
2. 左邊 **Internal Testing** 旁按 **＋**。
3. 群組名稱填 `本人`；勾選 **Enable automatic distribution**（自動發送新版本）→ **Create**。
4. 在群組頁的 **Testers** 旁按 **＋**，勾你自己的帳號 → **Add**。
   （內部測試員必須是 App Store Connect 的團隊成員；帳號持有人本來就是。）

## 5. 抄下 app 的 Apple ID（一串數字）

1. 在 app 頁面左邊點 **App Information**（在 General 底下）。
2. 抄下 **Apple ID**（純數字，例如四子棋的是 10 位數）。這不是你的 Apple 帳號，是這個 app 的編號。

## 6. 抄下 Team ID

1. 開 https://developer.apple.com/account
2. 往下捲到 **Membership details**，抄下 **Team ID**（10 碼英數字）。

## 7. 交給 invest-app

跟 invest-app 說「好了」，並貼上 **app 的 Apple ID**（第 5 步）。Team ID 備份說明檔裡已經有，第 6 步抄來只是讓 invest-app 核對一致。它們不是秘密，可以直接貼在對話裡。
描述檔留在 `~/Downloads` 就好。

invest-app 接著會：

- 確認描述檔的名稱、bundle id、綁的憑證都對，再把它從 `~/Downloads` 搬到 `~/.config/invest-mobile/ios/`；
- 把憑證、描述檔、API 金鑰和兩個代碼存成 app repo 的 GitHub secrets（寫進去以後連自己都讀不回來，別人也看不到）；
- 等網頁新版完成後，跑第一次上傳，送到 TestFlight。

## 8. iPhone 上安裝（第一個版本上傳後才做）

1. 從 App Store 安裝 **TestFlight**。
2. 收到 TestFlight 的邀請信（寄到你的 Apple ID 信箱）後，用 iPhone 打開信裡的連結，或直接開 TestFlight 按 **Accept**。
3. 安裝「個股研究室」。建議在 TestFlight 這個 app 的頁面打開 **Automatic Updates**，之後每次重建都會自動更新。

TestFlight 版本 90 天會過期；CI 每週檢查一次，快過期時會自動重建並推送，你不用做任何事。

## 一年一次要做的事（invest-app 會提前提醒）

- **發布憑證到期**（和四子棋同一張、同一天）：到期前要重做憑證和兩個 app 的描述檔，四子棋和個股研究室一起換。
- **Apple Developer Program 會費**：沒續約的話 TestFlight 和已上架的四子棋都會受影響。
- API 金鑰不會過期。
