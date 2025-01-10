@{
    COMMANDS = @{
        test = @{
            SYNTAX = '/test'
            DESCRIPTION = 'Test something!'
        }

    }

    ON_START = {

        function OnStartTest() {
            return (get-date);
        }


    }


    HANDLER = {
		param($res, $update)

        $res.mustReply = $true;
        $res.reply.message = "Success! $(OnStartTest)";
    }

}