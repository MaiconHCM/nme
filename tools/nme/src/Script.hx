import sys.net.Host;
import sys.net.Socket;


class Script
{
   static var socket:Socket;
   static var toSocket:haxe.io.Output;
   static var fromSocket:haxe.io.Input;

   public static function parseDeploy(inDeploy:String, inRequire:Bool, inForScript:Bool)
   {
      if (inDeploy==null || inDeploy=="")
      {
         if (inRequire)
            Log.error("A deployment target mmust be specified with 'deploy=...' or set deploy ...");
         return null;
      }

      var parts = inDeploy.split(":");
      if (parts.length>2)
         Log.error("deploy requires format [protocol:]name");

      if (parts.length>1 && parts[0]!="script")
         Log.error("A 'script:' protocol is required for this command, not " + inDeploy);

      if (parts.length==1)
          return { protocol:"script", name:inDeploy };
      return { protocol:parts[0], name:parts[1] };
   }

   public static function sendCommand(inCommand:Array<String>)
   {
      var message = "shell";
      toSocket.writeInt32(message.length);
      toSocket.writeString(message);

      toSocket.writeInt32(inCommand.length);
      for(c in inCommand)
      { 
         toSocket.writeInt32(c.length);
         toSocket.writeString(c);
      }
      var len = fromSocket.readInt32();
      return fromSocket.readString(len);
   }

   public static function parseInput() : Array<String>
   {
      Sys.print("=>");
      try
      {
         var line = Sys.stdin().readLine();
         var word:String;
         var result = new Array<String>();
         var pos = 0;
         while(pos<line.length)
         {
            var ch = line.charAt(pos++);
            if (ch!=" " && ch!="\t")
            {
               var quotes = false;
               var word = "";
               while(true)
               {
                  if (ch=="\\")
                  {
                     if (pos==line.length)
                     {
                        Sys.println("Bad trailing \\");
                        return [];
                     }
                     word += line.charAt(pos++);
                  }
                  else if (ch=='"')
                     quotes = !quotes;
                  else
                     word += ch;

                  if (pos==line.length)
                  {
                     if (quotes)
                     {
                        Sys.println("Unmatched quotes");
                        return [];
                     }
                     result.push(word);
                     break;
                  }
                  ch = line.charAt(pos++);
                  if ( (ch==" " || ch=="\t") && !quotes)
                  {
                     result.push(word);
                     break;
                  }
               }
            }
         }
         return result;
      }
      catch(e:Dynamic)
      {
         // EOF
      }
      return ["q"];
   }

   public static function shell(inPackageName:String, inHost:String, inCommand:Array<String>)
   {
      var target = parseDeploy(inHost,true,true);

      try
      {
         var host = new Host(target.name);
         Log.verbose("Connect to host " + host);

         socket = new Socket();

         socket.connect(host, 0xacad);
         toSocket = socket.output;
         fromSocket = socket.input;

         if (inCommand!=null && inCommand.length>0)
            sendCommand(inCommand);
         else
            while(true)
            {
               var command = parseInput();
               if (command.length>0)
               {
                  if (command[0]=="exit" || command[0]=="quit" || command[0]=="q")
                     break;
                  var response = sendCommand(command);
                  Sys.println(response);
               }
            }

         socket.close();
      }
      catch(e:Dynamic)
      {
         Log.error("Could not connect to " + inHost + " : " + e );
      }
   }
}


