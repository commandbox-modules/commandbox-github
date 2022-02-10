component {

    property name="fs" inject="FileSystem";
    property name="configService" inject="ConfigService";
    property name="hyper" inject="HyperBuilder@hyper";

    variables.accessTokenSettingName = "modules.commandbox-github.accessToken";

    function run() {
        if ( variables.configService.settingExists( variables.accessTokenSettingName ) ) {
            if ( !confirm( "You are already logged in. Do you want to log out and log in again?" ) ) {
                return;
            }
            variables.configService.removeSetting( variables.accessTokenSettingName );
        }

        var deviceCodes = variables.hyper
            .asJson()
            .withHeaders( { "Accept": "application/json" } )
            .post( "https://github.com/login/device/code", {
                "client_id": "03640f6d5cedcfd6a43e",
                "scope": "repo"
            } )
            .json();

        copyToClipboard( trim( deviceCodes.user_code ) );
        print.white( "Please enter the following code at #deviceCodes.verification_uri#: " ).boldGreenLine( deviceCodes.user_code );
        waitForKey( "Press any key to open that URL in your browser. (Press Ctrl-C to cancel.)" );
        print.line();
        command( "browse" )
            .params( deviceCodes.verification_uri )
            .run( returnOutput = true );
        print.yellowLine( "Waiting for authorization...." ).toConsole();

        for ( var time = 0; time <= deviceCodes.expires_in; time += deviceCodes.interval ) {
            sleep( deviceCodes.interval * 1000 );

            var accessCode = variables.hyper
                .asJson()
                .withHeaders( { "Accept": "application/json" } )
                .post( "https://github.com/login/oauth/access_token", {
                    "client_id": "03640f6d5cedcfd6a43e",
                    "device_code": deviceCodes.device_code,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
                } )
                .json();

            if ( accessCode.keyExists( "access_token" ) ) {
                variables.configService.setSetting( variables.accessTokenSettingName, accessCode.access_token );
                print.greenBoldUnderscoredLine( "Successfully logged in!" );
                return;
            }
        }

        error( "Timed out waiting for authorization from GitHub." );
    }

    private void function copyToClipboard( required string text ) {
        try {
            if ( variables.fs.isMac() ) {
                command( "run" ).params( 'echo -n "#text#"| pbcopy' ).run();
            } else if ( variables.fs.isWindows() ) {
                command( "run" ).params( 'echo #text#| clip' ).run();
            } else if ( variables.fs.isLinux() ) {
                command( "run" ).params( 'echo -n "#text#"| xclip -sel clip' ).run();
            }
        } catch ( any e ) {
            // clipboard not supported. move on.
            log.warn( "copyToClipboard failed", {
                "os": variables.fs.getOS(),
                "text": arguments.text,
                "error": e
            } );
        }
    }

}