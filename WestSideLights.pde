import processing.serial.*;

/*
#WestSideLights
2013 Jay Tavares

Control your Christmas lights via Twitter

Thanks to:
Paul Martis (http://www.digitalmisery.com/) for his amazing ColorNode board and Arduino software.
Michael Zick Doherty (http://neufuture.com) for figuring out how to get TwitterStream to work (and providing great sample code.)
Creators of Cheerlights (http://cheerlights.com) for the inspiration.

*/

/////////////////// Configurations! ///////////////////

// INSTRUCTIONS
//
// 1. Go to https://dev.twitter.com/apps
// 2. (If you haven't already) Create a new application for your WestSideLights
// 3. At the bottom of the application detail page, click "Create my access token"
// 4. Copy & paste your Consumer key, Consumer secret, Access token, and Access token secret below:

// This is where you enter your Twitter Oauth info
static String OAuthConsumerKey = "";
static String OAuthConsumerSecret = "";

// This is where you enter your Access Token info
static String AccessToken = "";
static String AccessTokenSecret = "";

// Serial port that the ColorNode controller is connected to
// Run the sketch to see a list of all available ports
static int colorNodePort = 0;

// Set this to the node id of the ColorNode you want controlled
// Setting to 255 will broadcast to all ColorNodes
static int nodeId = 255;

// Keywords to watch
// If no keywords are provided, a random sample of tweets will be collected
String keywords[] = {
  "#westsidelights",
  "@westsidelights",
  "westsidelights",
  "#cheerlights",
  "@cheerlights",
  "cheerlights"
};

// Number of pre-programmed chases that are in your ColorNodes
// 19 for ColorNode 1.0
// 26 for ColorNode 1.1
static int maxPrograms = 26;

// A place to hold the list of special commands
// {[text to match], [pre-programmed chase to run]}
// 99 : Randomly choose a chase
String[][] programs = {
  {"multi",             "1"},
  {"usa",              "14"},
  {"feliz navidad",    "15"},
  {"happy x-mas",      "16"},
  {"katie's favorite", "17"},
  {"merry christmas",  "18"},
  {"random",           "99"}
};

// Recipes for the colors
// 12-bit color
// Colors are identified with three decimal values from 0-15: R, G, B
// Color names are matched using regular expressions. This helps with multiword colors.
String[][] colors = {
  {"red", "15,0,0"},
  {"green", "0,15,0"},
  {"blue", "0,0,15"},
  {"yellow", "15,15,0"},
  {"cyan", "0,15,15"},
  {"magenta", "15,0,15"},
  {"black", "0,0,0"},
  {"indigo","6,0,15"},
  {"violet","8,0,15"},
  {"lavender", "14,14,15"},
  {"chartreuse", "7,15,0"},
  {"purple", "10,3,13"},
  {"turquoise", "4,14,13"},
  {"hooloovoo", "1,5,11"},
  {"pink", "15,6,8"},
  // multi word colors are matched a little differently
  {"(?<!warm\\s?)white", "15,15,15"}, // matches white, but not warm white or warmwhite
  {"warm\\s?white", "15,7,2"}, // matches warm white or warmwhite
  {"(?<!pale\\s?)orange", "15,1,0"}, // matches orange, but not pale orange or paleorange
  {"pale\\s?orange","8,1,0"} // matches pale orange or paleorange
};

/////////////////// End Configuration ///////////////////

TwitterStream twitter = new TwitterStreamFactory().getInstance();

Serial port; // The serial port to communicate with the ColorNode controller

void setup() {
  // Configure serial port connection
  
  // List all the available serial ports:
  println("Available serial ports:");
  println(Serial.list());
  // Open the correct serial port from the list (specified above)
  port = new Serial(this, Serial.list()[colorNodePort], 57600);
  
  // Handle connection to Twitter
  connectTwitter();
  twitter.addListener(listener);
  if (keywords.length==0) twitter.sample();
  else twitter.filter(new FilterQuery().track(keywords));
 
}

void draw() {
  // TODO: add some visualization so the app isn't so boring to look at
}

// Initial connection
void connectTwitter() {
  twitter.setOAuthConsumer(OAuthConsumerKey, OAuthConsumerSecret);
  AccessToken accessToken = loadAccessToken();
  twitter.setOAuthAccessToken(accessToken);
}

// Loading up the access token
private static AccessToken loadAccessToken() {
  return new AccessToken(AccessToken, AccessTokenSecret);
}

// This listens for new tweet
StatusListener listener = new StatusListener() {
  public void onStatus(Status status) {
    // New tweet received    
    println("@" + status.getUser().getScreenName() + " - " + status.getText());
    
    // A place to build the serial command
    String command = "";

    // Parse the message text
    String pgm = getProgram(status.getText());
    String nextColor = getColor(status.getText());
    
    // Was a program found?
    if (pgm.length() > 0) {
      // if random, select a program from 0 to maxPrograms
      if (pgm=="99") pgm = Integer.toString(int(random(maxPrograms)));
      // Build the command to turn on the program
      command = "1,0,0,0,0,0,0," + pgm + ",0," + nodeId + " l";
    }
    else if (nextColor.length() > 0) {
      // Build the command to set the color of the lights
      command = "2,0,36," + nextColor + ",200,0,0," + nodeId + " l";
    }
    if (command.length() > 0) {
      // A command was created, send it to the ColorNode(s)
      println("Writing command to serial: " + command);
      port.write(command);
    }
    else {
      println("No commands found. Ignoring tweet.");
    }
  }

  public void onDeletionNotice(StatusDeletionNotice statusDeletionNotice) {
    println("Got a status deletion notice id:" + statusDeletionNotice.getStatusId());
  }
  
  public void onTrackLimitationNotice(int numberOfLimitedStatuses) {
    println("Got track limitation notice:" + numberOfLimitedStatuses);
  }
  
  public void onScrubGeo(long userId, long upToStatusId) {
    println("Got scrub_geo event userId:" + userId + " upToStatusId:" + upToStatusId);
  }
  
  public void onException(Exception ex) {
    ex.printStackTrace();
  }
};

// Search the Tweet text for pre-defined command phrases
// and return the associated program number of the first one found
String getProgram(String tweetText) { 
  String result = "";
  // Loop through each one of the pre-defined command phrases and
  // search the Tweet text for its presence
  for (int i = 0; i < programs.length; i++) {
    if (tweetText.toLowerCase().indexOf(programs[i][0]) != -1) {
     result = programs[i][1];
    }
  }
  return result;
}

// Search the Tweet text for color keywords and 
// return the RGB formula for the first one found
String getColor(String tweet){
  // Returns code for first color in tweet
  String result = "";
  for(int i = 0; i < colors.length; i++){
    // Disable case sensitivity in regex match with (?i)
    String[] m1 = match(tweet, "(?i)"+colors[i][0]);
    if(m1 != null) result = colors[i][1];
  }
  return result;
}
