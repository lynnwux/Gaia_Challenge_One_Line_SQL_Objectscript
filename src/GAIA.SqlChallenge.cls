Class GAIA.SqlChallenge
{

Parameter REFSQL = "SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f))";
Parameter REFCOUNT = 57099;
Parameter OUTFILE = "/home/irisowner/dev/data/out/variable_objects.csv";

ClassMethod Run() As %Status
{
    Write "=== Gaia SQL Challenge ===",!
    Write "Table: g(id BIGINT, b TINYINT, f FLOAT)",!
    Write "b=0: BP band  b=1: RP band",!
    Write "Find all source IDs where flux varies >100% in either band.",!
    Write "Expected: ",..#REFCOUNT," rows",!!
    Write "Your SQL: "
    Read sql
    Write !

    // Run user SQL
    Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    If rs.%SQLCODE < 0 {
        Write "SQL error ",rs.%SQLCODE,": ",rs.%Message,!
        Do ..Judge(sql, -1, rs.%Message)
        Quit $$$OK
    }

    // Count result rows and write output
    Set count = 0
    Set f = ##class(%Stream.FileCharacter).%New()
    Set f.Filename = ..#OUTFILE
    Do f.WriteLine("source_id")
    While rs.%Next() { Do f.WriteLine(rs.%GetData(1))  Set count = count + 1 }
    Do f.%Save()

    Write "Your result: ",count," rows  (",($Length(sql))," chars)",!
    Write "Reference:   ",..#REFCOUNT," rows  (",($Length(..#REFSQL))," chars)",!

    If count = ..#REFCOUNT {
        Write "CORRECT!",!
    } Else {
        Write "Wrong count.",!
    }
    Write !

    Do ..Judge(sql, count, "")
    Quit $$$OK
}

ClassMethod Judge(sql As %String, count As %Integer, errMsg As %String)
{
    Set bearerToken = $System.Util.GetEnviron("BEDROCK_BEARER_TOKEN")
    If bearerToken = "" { Set bearerToken = $Get(^||ENV("BEDROCK_BEARER_TOKEN")) }
    If bearerToken = "" { Set bearerToken = $Get(^%AI.Config("BEDROCK_BEARER_TOKEN")) }
    If bearerToken = "" {
        Write "(Set BEDROCK_BEARER_TOKEN to enable AI commentary)",!
        Quit
    }

    Set provider = ##class(%AI.Provider).Create("bedrock", {"region": "us-east-1", "bearer_token": (bearerToken)})
    Set judge = ##class(GAIA.SqlJudge).%New()
    Set judge.Provider = provider
    Set judge.Model = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    Set sc = judge.%Init()
    If $$$ISERR(sc) { Write "(AI judge unavailable: ",sc,")",! Quit }

    Set session = judge.CreateSession()

    If errMsg '= "" {
        Set prompt = "User submitted this SQL: "_sql_$c(10)_"It produced a SQL error: "_errMsg
    } Else {
        Set chars = $Length(sql)
        Set gap = chars - $Length(..#REFSQL)
        Set prompt = "User SQL ("_chars_" chars, "_$Select(gap>0:"+"_gap_" over ref",gap=0:"ties ref",1:gap_" under ref — NEW RECORD")_"): "_sql_$c(10)_"Result: "_count_" rows (need "_..#REFCOUNT_")."
    }

    Write "AI Judge: "
    Set response = judge.Chat(session, prompt)
    Write response.Content,!!
}

}
