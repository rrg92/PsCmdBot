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
        $res = NewHandlerResult $this;
        $res.mustReply = $true;
        $res.reply.message = "Success! $(OnStartTest)";
        return $res;
    }

}