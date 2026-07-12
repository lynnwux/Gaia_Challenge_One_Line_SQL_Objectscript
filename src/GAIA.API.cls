Class GAIA.API Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/schema"  Method="GET"  Call="Schema"/>
  <Route Url="/preview" Method="GET"  Call="Preview"/>
  <Route Url="/run"     Method="POST" Call="Run"/>
  <Route Url="/judge"   Method="POST" Call="Judge"/>
</Routes>
}

ClassMethod Schema() As %Status
{
    Do ..WriteJSON({
        "table": "g",
        "description": "Gaia DR3 epoch photometry — one flux observation per row",
        "columns": [
            {"name":"id","type":"BIGINT","description":"Gaia source_id — unique star identifier"},
            {"name":"b","type":"TINYINT","description":"Band: 0 = BP (blue photometer), 1 = RP (red photometer)"},
            {"name":"f","type":"FLOAT","description":"Flux measurement in electrons/second for this observation"}
        ],
        "totalRows": 5668090,
        "goal": "Find all distinct star IDs where flux varies by more than 100% in either band",
        "answer": 57099
    })
    Quit $$$OK
}

ClassMethod Preview() As %Status
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 20 id,b,f FROM g ORDER BY id,b")
    Set rows = []
    While rs.%Next() {
        Do rows.%Push({"id":(rs.id),"b":(rs.b),"f":(rs.f)})
    }
    Do ..WriteJSON({"rows": (rows)})
    Quit $$$OK
}

ClassMethod Run() As %Status
{
    Set body = ##class(%DynamicObject).%FromJSON(%request.Content)
    Set sql = body.sql
    If sql = "" {
        Do ..WriteError("No SQL provided")
        Quit $$$OK
    }

    Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    If rs.%SQLCODE < 0 {
        Do ..WriteJSON({"error": (rs.%Message), "sqlcode": (rs.%SQLCODE)})
        Quit $$$OK
    }

    Set count = 0
    Set preview = []
    Set colCount = rs.%ResultColumnCount
    While rs.%Next() {
        Set count = count + 1
        If count <= 20 {
            Set row = {}
            For c = 1:1:colCount { Do row.%Set(rs.%GetMetadata().columns.GetAt(c).colName, rs.%GetData(c)) }
            Do preview.%Push(row)
        }
    }

    // Verify the actual ID set matches, not just the count.
    // Intersect user result with the reference answer — must be exactly 57099.
    Set refSQL = "SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f))"
    Set checkSQL = "SELECT COUNT(*) FROM ("_sql_") u JOIN ("_refSQL_") r ON u.id=r.id"
    Set crs = ##class(%SQL.Statement).%ExecDirect(, checkSQL)
    Set correct = 0
    If crs.%SQLCODE >= 0 && crs.%Next() { Set correct = (crs.%GetData(1) = 57099) && (count = 57099) }

    Do ..WriteJSON({
        "count": (count),
        "correct": (correct),
        "chars": ($Length(sql)),
        "refChars": 88,
        "gap": ($Length(sql) - 88),
        "preview": (preview)
    })
    Quit $$$OK
}

ClassMethod Judge() As %Status
{
    Set body = ##class(%DynamicObject).%FromJSON(%request.Content)
    Set quick = body.quick  // 1 = single-shot quip, 0 = end-of-round report

    If ..IsExpired() {
        Do ..WriteJSON({"roast": "The caddie has retired — this demo expired on September 8, 2026. Clone the repo at github.com/lynnwux/Gaia_Challenge_SQL_Golden_Tee, bring your own Bedrock key, and keep swinging. ⛳"})
        Quit $$$OK
    }

    Set tok = $System.Util.GetEnviron("BEDROCK_BEARER_TOKEN")
    If tok = "" { Set tok = $Get(^||ENV("BEDROCK_BEARER_TOKEN")) }
    If tok = "" {
        Do ..WriteJSON({"roast": "No API key — but the audacity of that SQL still lives rent free."})
        Quit $$$OK
    }

    Set provider = ##class(%AI.Provider).Create("bedrock", {"region": "us-east-1", "bearer_token": (tok)})
    Set agent = ##class(%AI.Agent).%New(provider)
    Set agent.Model = "us.anthropic.claude-haiku-4-5-20251001-v1:0"

    If quick {
        Set agent.SystemPrompt = "You are a veteran golf caddie who moonlights as a SQL wizard — snarky, Gen Z, deeply invested in this round. The challenge: table g(id BIGINT, b TINYINT, f FLOAT), b=0 BP band b=1 RP band. Find every distinct star id where MAX(f)>2*MIN(f) within a star+band group. Correct answer: exactly 57099 rows. Par is 88 chars. CRITICAL: some flux readings are stored as f=0 (invalid detector observations). A star with one f=0 trivially passes MAX(f)>2*MIN(f) because MIN becomes 0. Without filtering, the answer inflates to exactly 70688. f>0 is not optional — it is load-bearing. If the player gets 70688, they are missing f>0 and you must hint at this using a golf metaphor (e.g. their ball landed in a detector noise hazard, the fairway is full of ghost readings they need to clear out). For any other wrong count, name the specific flaw with a golf metaphor and give ONE targeted hint. When correct: hype the shot then roast or hype their char count vs par 88. 2-3 sentences max, no bullet points, no markdown."
        Set sql = body.sql
        Set count = body.count
        Set chars = body.chars
        Set errMsg = body.errMsg
        Set correct = body.correct
        If errMsg '= "" {
            Set prompt = "WRONG — SQL error: "_errMsg_" | SQL ("_chars_" chars): "_sql
        } ElseIf correct {
            Set gap = chars - 88
            Set prompt = "CORRECT — got 57099 rows | SQL ("_chars_" chars, "_$Select(gap>0:"+"_gap_" over par",gap=0:"exact par",1:gap_" under par, hole in one territory")_"): "_sql
        } Else {
            Set prompt = "WRONG — got "_count_" rows instead of 57099 | SQL ("_chars_" chars): "_sql
        }
    } Else {
        Set agent.SystemPrompt = "You are a veteran golf caddie who moonlights as a SQL wizard — snarky, Gen Z, the kind of caddie who remembers every shot. The challenge: find variable stars in table g(id BIGINT, b TINYINT, f FLOAT) where MAX(f)>2*MIN(f) per star per band, filtering f>0 to exclude invalid zero readings. Correct: 57099 rows, par=88 chars. Reference solution: SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f)). Give a 3-4 sentence end-of-round caddie report reviewing the full 9 holes using golf metaphors and Gen Z slang. Three possible endings: (1) Player got correct AND at or under par 88: go absolutely unhinged with praise, this is elite SQL golf. (2) Player got correct but best chars is above par 88: celebrate that they found the answer, roast the extra characters, then tell them the door is open to come back and go lower — end with exactly: 'You found the green but left strokes on the card, bestie — hit New Game and see if you can get to par or better.' then write '!!!!! SPOILER ALERT !!!!!' on its own line followed by the reference solution SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f)) and a one-sentence tip on tightening it up. (3) Player NEVER got correct: commiserate with genuine caddie heartbreak, review their best attempt, then after a dramatic buildup write '!!!!! SPOILER ALERT !!!!!' on its own line followed by the reference solution and a one-sentence explanation of why it works, then end with: 'The answer is yours now, bestie — or hit New Game if you feel gritty enough to earn it yourself.' No markdown, no bullet points, just flowing prose."
        Set history = body.history
        Set tries = body.tries
        Set bestCount = body.bestCount
        Set bestChars = body.bestChars
        Set prompt = "Player finished "_tries_" holes. Best: "_bestCount_" rows, "_bestChars_" chars (par=88, gap="_(bestChars-88)_"). Shots: "
        Set iter = history.%GetIterator(), i = 1
        While iter.%GetNext(.k, .attempt) {
            Set prompt = prompt_"H"_i_"="_attempt.chars_"c/"_attempt.count_"rows "
            Set i = i + 1
        }
    }

    Set session = agent.CreateSession()
    Set response = agent.Chat(session, prompt)
    Do ..WriteJSON({"roast": (response.Content)})
    Quit $$$OK
}

ClassMethod IsExpired() As %Boolean
{
    // Demo expires 60 days after launch: 2026-09-08
    Quit ($ZDate($H, 3) > "2026-09-08")
}

ClassMethod WriteJSON(obj As %DynamicObject)
{
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "utf-8"
    Do %response.SetHeader("Access-Control-Allow-Origin","*")
    Write obj.%ToJSON()
}

ClassMethod WriteError(msg As %String)
{
    Do ..WriteJSON({"error": (msg)})
}

}
