Class GAIA.Setup
{

ClassMethod Run() As %Status
{
    new $namespace
    set $namespace = "%SYS"

    Do ##class(Security.Services).Get("%Service_WebGateway", .sp)
    Set sp("AutheEnabled") = 96
    Do ##class(Security.Services).Modify("%Service_WebGateway", .sp)

    // Delete and re-create /api to ensure correct AutheEnabled
    Do ##class(Security.Applications).Delete("/api")
    Kill props
    Set props("AutheEnabled") = 64
    Set props("DispatchClass") = "GAIA.API"
    Set props("MatchRoles") = ":%All"
    Set props("NameSpace") = "USER"
    Set props("Enabled") = 1
    Set props("IsNameSpaceDefault") = 0
    Set sc = ##class(Security.Applications).Create("/api", .props)
    Write $Select(sc=1:"REST /api registered",1:"REST /api error "_sc),!

    // Delete and re-create /app to ensure correct AutheEnabled
    Do ##class(Security.Applications).Delete("/app")
    Kill props
    Set props("AutheEnabled") = 64
    Set props("Path") = "/home/irisowner/dev/www"
    Set props("MatchRoles") = ":%All"
    Set props("NameSpace") = "USER"
    Set props("Enabled") = 1
    Set props("IsNameSpaceDefault") = 0
    Set sc = ##class(Security.Applications).Create("/app", .props)
    Write $Select(sc=1:"CSP /app registered",1:"CSP /app error "_sc),!

    Quit $$$OK
}

}
