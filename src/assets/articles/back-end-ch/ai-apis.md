## AI 對話系統

本專案整合了台智雲（TWCC）、OpenAI 與 Google Gemini 的大型語言模型（LLM），透過 `langchaingo` 框架提供統一的 AI 對話服務。該系統支援標準對話、串流輸出（Streaming）以及工具調用（Tool Calling）功能，並透過不同的 API 路徑（Endpoint）來決定使用的供應商。

### 技術架構
- **框架**：[langchaingo](https://github.com/tmc/langchaingo)
- **供應商支援**：台智雲 (TWCC)、OpenAI、Google Gemini
- **架構設計**：採用**按需載入 (Lazy Loading)** 與 **Endpoint 驅動**。只需在 `.env` 中填寫想使用的供應商金鑰，並呼叫對應的 API 路徑即可，未設定的供應商不會影響系統啟動。
- **並發控制**：系統設有全域並發限制（Semaphore），以確保伺服器穩定性。
- **日誌記錄**：所有 AI 對話請求與回應（包含 Token 使用量、延遲、所使用的供應商等）都會自動記錄於 `ai_chatlog` 資料庫中。

---

## 對話日誌記錄 (ai_chatlog)

為了進行系統審核與效能追蹤，API會將每一次的對話細節儲存於 `ai_chatlog` 資料表中。

| 欄位名稱 | 類型 | 描述 |
| --- | --- | --- |
| `id` | `int64` | 主鍵，自動遞增。 |
| `session` | `string` | 該次對話的階段 ID。 |
| `user_id` | `string` | 發起請求的用戶 ID。 |
| `provider` | `string` | 處理該次請求的 AI 供應商名稱 (`twcc`, `openai`, `gemini`)。 |
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

系統支援隨插即用的配置方式。您**只需填寫您想使用的 AI 服務的相關變數**，未填寫的服務對應的 API 將會回傳配置錯誤，但不會影響後端啟動。

### 全域控制參數

| 變數名稱 | 預設值 | 描述 |
| --- | --- | --- |
| `AI_TIMEOUT` | `60` | API 調用逾時時間（秒）。 |
| `AI_MAX_RETRY` | `2` | 失敗時的自動重試次數（僅限非串流模式）。 |
| `AI_MAX_CONCURRENT` | `100` | 系統允許的最大 AI 並發請求數。 |

### 供應商特定參數

| 變數名稱 | 預設值 | 描述 |
| --- | --- | --- |
| `TWCC_API_URL` | `https://api-ams.twcc.ai/api` | 台智雲 API 基礎網址。 |
| `TWCC_API_KEY` | - | 您的台智雲 API 金鑰。 |
| `TWCC_MODEL` | `llama3.3-ffm-70b-16k-chat` | 台智雲使用的模型名稱。 |
| `OPENAI_API_URL`| `https://api.openai.com/v1` | OpenAI API 基礎網址。 |
| `OPENAI_API_KEY`| - | 您的 OpenAI API 金鑰。 |
| `OPENAI_MODEL` | `gpt-4o` | OpenAI 使用的模型名稱。 |
| `GEMINI_API_URL`| `https://generativelanguage.googleapis.com` | Gemini API 基礎網址。 |
| `GEMINI_API_KEY`| - | 您的 Google Gemini API 金鑰。 |
| `GEMINI_MODEL` | `gemini-1.5-pro` | Gemini 使用的模型名稱。 |

---

## APIs

系統提供三個獨立的 API 路徑來呼叫不同的模型供應商，**它們的 Request / Response 格式完全一致**。

| 供應商 | HTTP 方法 | Endpoint | 描述 |
| --- | --- | --- | --- |
| **台智雲 (TWCC)** | `POST` | `/ai/chat/twai` | 呼叫台智雲模型 |
| **OpenAI** | `POST` | `/ai/chat/openai` | 呼叫 OpenAI 模型 |
| **Google Gemini** | `POST` | `/ai/chat/gemini` | 呼叫 Gemini 模型 |

*注意：若呼叫某個 API 但對應的 API_KEY 未在 `.env` 中設定，將會回傳 `500 AI_SERVICE_ERROR`。*

### API 請求規格 (適用於所有 Provider)

| 項目 | 描述 |
| --- | --- |
| 權限 | `User` (需要登入) |
| 認證 | `Authorization: Bearer <JWT_TOKEN>` |

#### Request Body (AIChatInput)

本 API 的參數設計高度參考了 [台智雲官方 API 規範](https://docs.twcloud.ai/docs/user-guides/twcc/afs/api-and-parameters/api-parameter-information)。

| 參數 | 類型 | 必填 | 描述 |
| --- | --- | --- | --- |
| `session` | `string` | 否 | 對話階段 ID，若未提供系統將自動生成。 |
| `stream` | `boolean` | 否 | 是否開啟串流模式（SSE）。預設為 `false`。 |
| `messages` | `array` | 是 | 對話歷史清單。每一項需包含 `role` (`system`, `user`, `assistant`, `tool`) 與 `content`。若涉及工具調用，需額外包含 `tool_calls` (由 assistant 回傳) 與 `tool_call_id` (由 tool 提供)。 |
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
    "session": "session_1234567890",
    "stream": false,
    "messages": [
        {
            "role": "system",
            "content": "你是台北市城市儀表板的導覽專家。"
        },
        {
            "role": "user",
            "content": "請告訴我今天日期，並幫我查詢台北市2023年的人口結構概況"
        }
    ],
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 50,
    "max_new_tokens": 500,
    "frequence_penalty": 1.1,
    "stop_sequences": [
        "###",
        "END"
    ],
    "seed": 42,
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "get_current_time",
                "description": "取得伺服器目前的台北時間"
            }
        },
        {
            "type": "function",
            "function": {
                "name": "get_population_summary",
                "description": "查詢台北市或新北市特定年份的人口年齡分佈數據，包含幼年、青壯年及老年人口數。",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "city": {
                            "type": "string",
                            "description": "城市名稱",
                            "enum": [
                                "taipei",
                                "new_taipei"
                            ]
                        },
                        "year": {
                            "type": "integer",
                            "description": "查詢年份，例如 2023"
                        }
                    },
                    "required": [
                        "city",
                        "year"
                    ]
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
    "data": {
        "content": "今天的日期是2026-04-09，且為您查到台北市於2023年的人口結構概況。根據結果顯示：\n- 幼年人口 (0-14歲) 有 310069 人。\n- 青壯年人口 (15-64歲) 有 1648662 人。\n- 老年人口 (65歲以上) 有 553155 人。\n- 總人口為 2511886 人。\n- 數據最後更新時間是在2025-02-19。",
        "latency_ms": 7176,
        "model": "llama3.3-ffm-70b-16k-chat",
        "provider": "twcc",
        "session": "session_1234567890",
        "tool_used": true,
        "usage": {
            "input_tokens": 1938,
            "output_tokens": 152,
            "total_tokens": 2090
        }
    },
    "status": "success"
}
```

---

### 進階功能

#### 串流輸出 (Streaming)
當 `stream` 設為 `true` 時，後端將回傳 `text/event-stream`。內容會隨著模型生成即時推送至客戶端。

#### 工具調用 (Tool Calling)
本 API 支援智慧型工具調用。若請求中包含 `tools` 定義，模型可根據需求決定調用特定工具（如查詢即時交通資料）。後端會自動執行對應工具並將結果回饋給模型，直到生成最終回答為止（最多循環 5 次）。

#### 並發限制 (Semaphore)
為了保護伺服器免於過載，系統使用了 Go 訊號量（Semaphore）進行並發控制。最大並發數由 `AI_MAX_CONCURRENT` 設定，超過限制時將回傳 `500 Server too busy`。

---

## 實作架構與開發者指南

本節專為後端開發者設計，詳述 AI 對話服務的內部實作細節。

### 1. 請求生命週期與資料流轉

1.  **控制器層 (Controller)**: 接收前端請求，驗證權限，並根據 Endpoint 決定 Provider。
2.  **業務邏輯層 (Service)**: 建立 `aiSession` 狀態機，並呼叫 `injectInstructions()`。
3.  **適配器層 (Provider)**: 將通用請求轉換為特定供應商（如 TWCC AFS 或 OpenAI）專用的格式。
4.  **對話迴圈 (The Loop)**: 
    *   模型生成結果。
    *   若偵測到工具呼叫（JSON 或 XML 格式），則由後端 `executeTools()` 執行 Go 函數。
    *   將工具執行結果作為 `role: tool` 附加回對話紀錄，再次請求模型，直到獲得最終答案（上限 5 次）。
5.  **日誌紀錄 (Logging)**: 最終結果寫入 `ai_chatlog` 資料庫。

### 2. 檔案職責說明

| 檔案路徑 | 職責說明 |
| :--- | :--- |
| `app/controllers/ai.go` | 參數校驗、隨機 Session 生成、分發 Provider。 |
| `app/services/ai/ai_service.go` | **核心狀態機**。處理工具執行迴圈、Token 統計與並發限制。 |
| `app/services/ai/providers/factory.go` | **模型工廠**。負責按需初始化與緩存不同供應商的實例。 |
| `app/services/ai/tools/registry.go` | **工具中央樞紐**。負責工具函數的註冊與反射執行。 |

### 3. 關鍵技術細節

#### 串流模式下的靜默攔截 (Silent Interception)
為了避免使用者在串流中看到模型噴出的工具呼叫（如 `<function=...>`），系統實作了攔截邏輯：
*   **偵測期**: 緩衝前 64 個字元，判斷是否包含工具指令。
*   **靜默期**: 若確認為工具調用，後端會持續累積數據但不發送給前端，直到工具執行完畢。
*   **轉發期**: 工具結果回饋給模型後產生的「純文字答案」才會流向前端。

#### AFS 模型幻覺修正 (僅限 TWCC)
台智雲模型有時會在對話歷史中殘留非法 XML 標籤，導致下一輪請求失敗。系統會在發送請求前自動清理這些內容。

### 4. 如何新增一個 AI 工具 (Extension Guide)

開發者只需簡單兩步即可擴充 AI 的能力：

1.  **實作工具函數**: 在 `app/services/ai/tools/` 下新增一個符合簽名的函數：
    ```go
    func MyNewTool(ctx context.Context, args string) (string, error) {
        // 解析參數並執行邏輯
        return "結果字串", nil
    }
    ```
2.  **註冊工具**: 在 `registry.go` 的 `init()` 中註冊：
    ```go
    func init() {
        Register("my_tool_name", MyNewTool)
    }
    ```
