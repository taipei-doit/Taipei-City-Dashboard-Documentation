## AI 對話系統

本專案整合了台智雲（TWCC）的大型語言模型（LLM），透過 `langchaingo` 框架提供 AI 對話服務。該系統支援標準對話、串流輸出（Streaming）以及工具調用（Tool Calling）功能。

### 技術架構
- **框架**：[langchaingo](https://github.com/tmc/langchaingo)
- **供應商**：台智雲 (TWCC)
- **並發控制**：系統設有並發限制（Semaphore），以確保伺服器穩定性。
- **日誌記錄**：所有 AI 對話請求與回應（包含 Token 使用量、延遲等）都會自動記錄於 `ai_chatlog` 資料庫中。

---

## 對話日誌記錄 (ai_chatlog)

為了進行系統審核與效能追蹤，後端會自動將每一次的對話細節儲存於 `ai_chatlog` 資料表中。

| 欄位名稱 | 類型 | 描述 |
| --- | --- | --- |
| `id` | `int64` | 主鍵，自動遞增。 |
| `session_id` | `string` | 該次對話的階段 ID。 |
| `user_id` | `string` | 發起請求的用戶 ID。 |
| `provider` | `string` | AI 供應商名稱（預設為 `twcc`）。 |
| `model` | `string` | 使用的模型名稱。 |
| `question` | `text` | 用戶發送的最後一則訊息內容。 |
| `answer` | `text` | 模型生成的最終回覆內容。 |
| `tool_used` | `bool` | 是否曾在對話過程中調用過工具。 |
| `tools` | `jsonb` | 調用過的工具詳細資訊（JSON 格式）。 |
| `input_tokens` | `int` | 輸入所消耗的 Token 數量。 |
| `output_tokens`| `int` | 輸出所消耗的 Token 數量。 |
| `total_tokens` | `int` | 總消耗 Token 數量。 |
| `latency_ms` | `int` | 請求延遲時間（毫秒）。 |
| `status` | `string` | 請求狀態（如 `success`, `error`）。 |
| `error_code` | `string` | 若發生錯誤時的錯誤代碼。 |
| `error_message`| `text` | 若發生錯誤時的詳細錯誤訊息。 |
| `ip_address` | `string` | 發起請求的客戶端 IP 位址。 |
| `created_at` | `time` | 記錄建立的時間。 |

---

## 環境變數配置

在主專案的 `.env` 檔案中，需配置以下變數以啟用 AI 功能：

| 變數名稱 | 預設值 | 描述 |
| --- | --- | --- |
| `TWCC_API_URL` | `https://api-ams.twcc.ai/api` | 台智雲 API 基礎網址。 |
| `TWCC_API_KEY` | - | 您的台智雲 API 金鑰。 |
| `TWCC_MODEL` | `llama3.3-ffm-70b-32k-chat` | 使用的模型名稱。 |
| `TWCC_TIMEOUT` | `60` | API 調用逾時時間（秒）。 |
| `TWCC_MAX_RETRY` | `2` | 失敗時的自動重試次數（僅限非串流模式）。 |
| `TWCC_MAX_CONCURRENT` | `100` | 系統允許的最大 AI 並發請求數。 |

---

## APIs

### AI 對話 (TWCC)

`POST` `/ai/chat/twai`

此 API 允許用戶與台智雲模型進行對話。支援多輪對話、模型參數調整及串流回應。

| 項目 | 描述 |
| --- | --- |
| 權限 | `User` (需要登入) |
| 認證 | `Authorization: Bearer <JWT_TOKEN>` |

#### Request Body (AIChatInput)

本 API 的參數設計高度參考了 [台智雲官方 API 規範](https://docs.twcloud.ai/docs/user-guides/twcc/afs/api-and-parameters/api-parameter-information)。

| 參數 | 類型 | 必填 | 描述 |
| --- | --- | --- | --- |
| `session_id` | `string` | 否 | 對話階段 ID，若未提供系統將自動生成。 |
| `stream` | `boolean` | 否 | 是否開啟串流模式（SSE）。預設為 `false`。 |
| `messages` | `array` | 是 | 對話歷史清單。每一項需包含 `role` 與 `content`。 |
| `temperature` | `float` | 否 | 控制生成結果的隨機性 (0.0 - 1.0)。 |
| `max_new_tokens` | `int` | 否 | 限制模型生成的最大 Token 數量。 |
| `top_p` | `float` | 否 | 核採樣 (Nucleus Sampling) 閾值 (0.0 - 1.0)。 |
| `top_k` | `int` | 否 | 從概率最高的 K 個 Token 中進行採樣 (1 - 100)。 |
| `frequence_penalty`| `float` | 否 | 頻率懲罰係數，減少重複字詞。 |
| `stop_sequences` | `array` | 否 | 模型停止生成的字串列表 (最多 4 個)。 |
| `seed` | `int` | 否 | 隨機種子，用於獲得穩定的輸出結果。 |
| `tools` | `array` | 否 | 可供模型調用的工具列表。 |
| `tool_choice` | `any` | 否 | 指定工具調用模式。 |

**範例 (完整參數):**

```json
{
  "session_id": "test_session_12345",
  "stream": false,
  "messages": [
    { "role": "system", "content": "你是一個台北市的導覽專家。" },
    { "role": "user", "content": "推薦我三個台北市的景點，並告訴我現在的天氣。" }
  ],
  "temperature": 0.7,
  "top_p": 0.9,
  "top_k": 50,
  "max_new_tokens": 500,
  "frequence_penalty": 1.1,
  "stop_sequences": ["###", "END"],
  "seed": 42,
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_current_weather",
        "description": "取得特定地點的目前天氣狀況",
        "parameters": {
          "type": "object",
          "properties": {
            "location": { "type": "string", "description": "城市名稱，例如：Taipei" }
          },
          "required": ["location"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
```

#### Response (非串流)

**Success (200 OK):**

```json
{
  "status": "success",
  "data": {
    "session_id": "test_session",
    "content": "當然！這裡有三個推薦的景點...",
    "usage": {
      "input_tokens": 42,
      "output_tokens": 256,
      "total_tokens": 298
    },
    "tool_used": false,
    "latency_ms": 1850,
    "model": "llama3.3-ffm-70b-32k-chat",
    "provider": "twcc"
  }
}
```

---

### 進階功能

#### 串流輸出 (Streaming)
當 `stream` 設為 `true` 時，後端將回傳 `text/event-stream`。內容會隨著模型生成即時推送至客戶端。

#### 工具調用 (Tool Calling)
本 API 支援智慧型工具調用。若請求中包含 `tools` 定義，模型可根據需求決定調用特定工具（如查詢即時交通資料）。後端會自動執行對應工具並將結果回饋給模型，直到生成最終回答為止（最多循環 5 次）。

#### 並發限制 (Semaphore)
為了保護伺服器免於過載，系統使用了 Go 訊號量（Semaphore）進行並發控制。最大並發數由 `TWCC_MAX_CONCURRENT` 設定，超過限制時將回傳 `500 Server too busy`。
