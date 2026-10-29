# 低能手指指

一個基於手勢識別的 macOS 虛擬滑鼠指針控制App。

## 功能

- **手勢追蹤**：利用相機與 Vision 框架即時偵測手部關鍵點。
- **滑鼠控制**：將手勢動作映射至 macOS 滑鼠游標與點擊操作。
- **平滑濾波**：過濾抖動，提供更流暢的指針移動體驗。

## 系統需求 

- macOS 26.0+
- Xcode 16.0+
- 支援相機權限與輔助功能控制權限

## 設計與體驗規範

- **Apple HIG**：本專案在 UI/UX、互動邏輯及權限指引上，請務必遵循 [Apple Human Interface Guidelines (HIG)](https://developer.apple.com/design/human-interface-guidelines/)，確保原生且流暢的 macOS 使用者體驗。

## License

本專案採用 **[Mozilla Public License 2.0 (MPL 2.0)](LICENSE)** 授權。

- 只要你修改了本專案既有的原始碼檔案，該修改後的檔案需保持以 MPL 2.0 開源。
- 你可以自由引用、整合至其他商業或專有軟體中，且你自己的專案程式碼無須強制開源。
