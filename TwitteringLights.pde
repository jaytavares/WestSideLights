import processing.serial.*;

/*
TwitteringLights
#westsidelights
2012 Jay Tavares

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
// 2. (If you haven't already) Create a new application for your TwitteringLights
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
static int colorNodePort = 4;

// keywords to watch
String keywords[] = {
  "#westsidelights",
  "@westsidelights",
  "westsidelights",
  "#cheerlights",
  "@cheerlights",
  "cheerlights"
};

// Number of pre-programmed chases that are in your ColorNodes
static int maxPrograms = 18;

// A place to hold the list of special commands
// {[text to match], [pre-programmed chase to run]}
// 99 : Randomly choose a chase
String[][] programs = {  
  {"usa",              "14"},
  {"feliz navidad",    "15"},
  {"happy x-mas",      "16"},
  {"katie's favorite", "17"},
  {"merry christmas",  "18"},
  {"random",           "99"}
};

// Recipes for the colors
String[][] colors = {
  {"red", "15,0,0"},
  {"green", "0,15,0"},
  {"blue", "0,0,15"},
  {"yellow", "15,15,0"},
  {"cyan", "0,15,15"},
  {"magenta", "15,0,15"},
  {"black", "0,0,0"},
  {"white", "15,15,15"},
  {"warmwhite", "15,7,2"},
  {"purple", "10,3,13"},
  {"orange", "15,1,0"},
  {"paleorange","8,1,0"},
  {"indigo","6,0,15"},
  {"violet","8,0,15"},
  {"chartreuse", "7,15,0"}
};

/////////////////// End Configuration ///////////////////

TwitterStream twitter = new TwitterStreamFactory().getInstance();

Serial port; // The serial port to communicate with the ColorNode controller

void setup() {
  // Configure serial port connection
  
  // List all the available serial ports:
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
    
    String command = "";

    // Parse the message text
    String pgm = getProgram(status.getText());
    String nextColor = getColor(status.getText());
    
    if (pgm.length() > 0) {
      // if random, select a program from 0 to maxPrograms
      if (pgm=="99") pgm = Integer.toString(int(random(maxPrograms + 1)));
      command = "1,0,0,0,0,0,0," + pgm + ",0,1 l";
    }
    else if (nextColor.length() > 0) {
      command = "2,0,35," + nextColor + ",200,0,0,1 l";
    }
    if (command.length() > 0) {
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

String getProgram(String tweetText) {
  String result = "";
  for (int i = 0; i < programs.length; i++) {
    if (tweetText.toLowerCase().indexOf(programs[i][0]) != -1) {
     result = programs[i][1];
    }
  }
  return result;
}

String getColor(String tweetText) {
  String result = "";
  
  String[] tokens = splitTokens(tweetText);
  
  for (int i = 0; i < tokens.length; i++) {
    for (int j = 0; j < colors.length; j++) {
      if (tokens[i].toLowerCase().equals(colors[j][0])) {
        result = colors[j][1];
      }
    }
  }
  return result;
}
