component {

    property name="packageService" inject="PackageService";
    property name="jsonService" inject="JSONService";
    property name="fs" inject="FileSystem";
    property name="hyper" inject="HyperBuilder@hyper";
    property name="progressBarGeneric" inject="progressBarGeneric";

    variables.accessTokenSettingName = "modules.commandbox-github.accessToken";

    function run() {
        if ( !variables.configService.settingExists( variables.accessTokenSettingName ) ) {
            command( "gh login" ).run();
            print.line().line();
        }
        var accessToken = variables.configService.getSetting( variables.accessTokenSettingName, "" );

        if ( !variables.packageService.isPackage( getCWD() ) ) {
            error( "This command must be ran in the root of a package containing a `box.json` file." );
        }

        var boxJSON = variables.packageService.readPackageDescriptor( getCWD() );
        var installPaths = variables.jsonService.show( boxJSON, "installPaths", {} );

        print.line( "Starring repos..." ).toConsole();
        var currentCount = 0;
        variables.progressBarGeneric.update(
            percent = 0,
            currentCount = currentCount,
            totalCount = installPaths.len()
        );

        var starResults = installPaths.map( ( name, path ) => {
            var modulePath = variables.fs.resolvePath( path );
            if ( !variables.packageService.isPackage( modulePath ) ) {
                currentCount++;
                variables.progressBarGeneric.update(
                    percent = ( currentCount / installPaths.len() ) * 100,
                    currentCount = currentCount,
                    totalCount = installPaths.len()
                );
                return {
                    "error": true,
                    "statusCode": 404,
                    "data": "#path# is not a module"
                };
            }
            var moduleBoxJSON = variables.packageService.readPackageDescriptor( modulePath );
            var repositoryURL = variables.jsonService.show( moduleBoxJSON, "repository.URL", "" );
            if ( repositoryURL.findNoCase( "github" ) == 0 ) {
                currentCount++;
                variables.progressBarGeneric.update(
                    percent = ( currentCount / installPaths.len() ) * 100,
                    currentCount = currentCount,
                    totalCount = installPaths.len()
                );
                return {
                    "error": true,
                    "statusCode": 404,
                    "data": "#path# is not a GitHub module"
                };
            }
            var repo = repositoryURL.listToArray( "/" ).slice( -1 ).toList( "/" );
            var res = hyper
                .asJson()
                .withHeaders( {
                    "Authorization": "Bearer #accessToken#",
                    "Accept": "application/vnd.github.v3+json",
                    "Content-Length": 0,
                } )
                .put( "https://api.github.com/user/starred/#repo#" );

            currentCount++;
            variables.progressBarGeneric.update(
                percent = ( currentCount / installPaths.len() ) * 100,
                currentCount = currentCount,
                totalCount = installPaths.len()
            );

            return {
                "error": res.isError(),
                "statusCode": res.getStatusCode(),
                "data": res.isError() ? repo & ": " & res.json().message : ""
            };
        }, true );

        variables.progressBarGeneric.update(
            percent = 100,
            currentCount = installPaths.len(),
            totalCount = installPaths.len()
        );

        print.table(
            data = starResults.keyArray().map( ( repo ) => ( {
                "Repository": repo,
                "Result": {
                    "value": starResults[ repo ].error ? "✗" : "✓",
                    "options": starResults[ repo ].error ? "red" : "green"
                },
                "Message": starResults[ repo ].data
            } ) ),
            includedHeaders = [ "Repository", "Result", "Message" ],
            headerNames = [ "Repository", "Result", "Message" ]
        );
    }

}