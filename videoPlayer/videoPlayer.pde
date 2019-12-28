import processing.video.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
Movie myMovie;
FeedbackWidget feedbackbWidget;

// These are the 4 sections START times, in seconds.
// Edit to your needs, but make sure to keep the values within the bounds of your video duration.
float[] sectionStarts = { 0, 10, 20, 30}; 

// These are the 4 sections END times, in seconds.
// Edit to your needs, but make sure to keep the values within the bounds of your video duration.
float[] sectionEnds = { 10, 20, 30, 40}; 

String[] sectionLabels = { "Soft singing", "Louder singing", "Soft noise", "Loud noise"}; 
float[] currentTimes = sectionStarts;
boolean[] playing = { false, false, false, false}; 
float[] sectionLikelihoods = {0, 0, 0, 0};

Movie[] movies;
PVector[] movieOrigins;

// local copy of the thresholds used by the audio analysis
float ampThreshold_0 = 0.5;
float ampThreshold_1 = 0.5;


// super collider server address
NetAddress scHost;

// Display modes
enum Page {
  PRACTICE, PLAY
};
Page currentPage = Page.PRACTICE;

public void settings() {
  size(800, 600);
}


void setup() {

  scHost = new NetAddress("127.0.0.1", 57120);

  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 12000);
  oscP5.plug(this, "updateLikelihood", "/likelihood");
  oscP5.plug(this, "updateAmpThreshold_0", "/ampTresh_0");
  oscP5.plug(this, "updateAmpThreshold_1", "/ampTresh_1");



  // widget size
  int size = height/10;
  feedbackbWidget = new FeedbackWidget(width/2, height - size, size, size);

  movies = new Movie[4];
  movieOrigins = new PVector[4];

  for (int i = 0; i<4; i++) {
    movies[i] = new Movie(this, "testVideo.mov");
    movies[i].noLoop();
  }

  // mosaic movies layout
  //movieOrigins[0] = new PVector(0, 0);
  //movieOrigins[1] = new PVector(width/2, 0);
  //movieOrigins[2] = new PVector(0, height/2);
  //movieOrigins[3] = new PVector(width/2, height/2);

  // stack movies layout
  movieOrigins[0] = new PVector(width/4, height/4);
  movieOrigins[1] = new PVector(width/4, height/4);
  movieOrigins[2] = new PVector(width/4, height/4);
  movieOrigins[3] = new PVector(width/4, height/4);
}

void mouseDragged() {
  if (currentPage == Page.PRACTICE) {


    if (mouseY > height / 2) {
      // bottom slider: update amp threshold for singing sounds
      ampThreshold_0 = float(mouseX) / width;
      println("AMP THRESH - SINGING " + str(ampThreshold_0));
    } else {
      // upper slider: update amp threshold for noise sounds
      ampThreshold_1 = float(mouseX) / width;
      println("AMPR THRESH - NOISE " + str(ampThreshold_1));
    }

    updateSuperColliderThresholds();
  }
}

void updateSuperColliderThresholds() {
  OscMessage myMessage = new OscMessage("/updateThresholds");
  myMessage.add(ampThreshold_0); 
  myMessage.add(ampThreshold_1); 
  oscP5.send(myMessage, scHost);
}


void draw() {
  clear();

  if (keyPressed) {
    if (key == ' ') {
      if (currentPage == Page.PRACTICE) {
        currentPage = Page.PLAY;
        println("PLAY");
      } else {
        currentPage = Page.PRACTICE;
        println("PRACTICE");
      }
    } else {
      currentPage = Page.PRACTICE;
    }
  }

  if (currentPage == Page.PLAY) {
    for (int i = 0; i<4; i++) {
      drawVideo(i);
    }
  } else {
    reinitMovies();
  }



  if (currentPage == Page.PRACTICE) {

    // draw decision thresholds as vertical lines
    textSize(16);
    fill(60);
    stroke(30);
    // draw bottom slider
    line(ampThreshold_0 * width, height/2, ampThreshold_0 * width, height);
    text(str(ampThreshold_0), ampThreshold_0 * width, height*3/4);
     // draw upper slider 
    line(ampThreshold_1 * width, 0, ampThreshold_1 * width, height/2);
    text(str(ampThreshold_1), ampThreshold_1 * width, height/4);

    // draw large feedback widget
    feedbackbWidget.x = width/2;
    feedbackbWidget.y = height/2;
    feedbackbWidget.w = width/3;
    feedbackbWidget.h = width/3;

    // draw audio category labels
    textSize(32);
    fill(100);
    text(sectionLabels[2], 50, 32);
    text(sectionLabels[0], 50, height - 50);
    text(sectionLabels[1], width/2 + 50, height - 50);
    text(sectionLabels[3], width/2 + 50, 32);
  } else {
    int size = height/10;
    feedbackbWidget.x = width/2;
    feedbackbWidget.y = height - size;
    feedbackbWidget.w = size;
    feedbackbWidget.h = size;
  }

  feedbackbWidget.update(sectionLikelihoods[1], 
    sectionLikelihoods[0], 
    sectionLikelihoods[2], 
    sectionLikelihoods[3]
    );

  feedbackbWidget.display();
}

void reinitMovies() {
  currentTimes = sectionStarts;
  for (int i = 0; i<4; i++) {
    movies[i].jump(currentTimes[i]);
    movies[i].stop();
    playing[i] = false;
  }
}

void drawVideo(int i) {


  if (currentTimes[i] >= sectionEnds[i]) {
    currentTimes[i] = sectionStarts[i];
  }

  if (sectionLikelihoods[i] > 0.1) {
    if (!playing[i]) {
      movies[i].play();
      movies[i].jump(currentTimes[i]);
      playing[i] = true;
    } else {
      currentTimes[i] = movies[i].time();
    }

    tint(255, sectionLikelihoods[i]*255);
    image(movies[i], movieOrigins[i].x, movieOrigins[i].y, width/2, height/2);
    movies[i].volume(sectionLikelihoods[i]);
  } else {
    movies[i].pause();
    playing[i] = false;
  }
}

// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}


/////////////// OSC CALLBACKS

// update section likelihood value
public void updateLikelihood(int section, float value) {
  sectionLikelihoods[section] = value;
}

// update section likelihood value
public void updateAmpThreshold_0(float value) {
  //println("osc in AMP thresh " + str(value));
  ampThreshold_0 = value;
}
// update section likelihood value
public void updateAmpThreshold_1(float value) {
  //println("osc in AMP thresh " + str(value));
  ampThreshold_1 = value;
}
