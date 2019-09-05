import processing.video.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
Movie myMovie;
FeedbackWidget feedbackbWidget;

float[] sectionStarts = { 1066, 745, 120, 386}; 
float[] sectionEnds = { 1186, 864, 381, 418}; 
String[] sectionLabels = { "Soft singing", "Louder singing", "Clap", "Shhhhhhh"}; 
float[] currentTimes = sectionStarts;
boolean[] playing = { false, false, false, false}; 
float[] sectionLikelihoods = {0, 0, 0, 0};

int sectionCount = 7;
int currentSection = -1;
int pitchSections = 3;
Movie[] movies;

PVector[] movieOrigins;

enum Page {
  PRACTICE, PLAY
};
Page currentPage = Page.PRACTICE;

public void settings() {
  size(800, 600);
}


void setup() {
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 12000);
  oscP5.plug(this, "updateLikelihood", "/likelihood");

  // widget size
  int size = height/10;
  feedbackbWidget = new FeedbackWidget(width/2, height - size, size, size);

  movies = new Movie[4];
  movieOrigins = new PVector[4];

  for (int i = 0; i<4; i++) {
   movies[i] = new Movie(this, "video.mp4");
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



void draw() {
  clear();

  if (keyPressed) {
    if (key == ' ') {
      if (currentPage == Page.PRACTICE){
        currentPage = Page.PLAY;
        println("PLAY");
      } else {
      currentPage = Page.PRACTICE;
      println("PRACTICE");
      }
      
    } else {
      currentPage = Page.PLAY;
      
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
    feedbackbWidget.x = width/2;
    feedbackbWidget.y = height/2;
    feedbackbWidget.w = width/2;
    feedbackbWidget.h = width/2;

    textSize(32);
    fill(100);
    text(sectionLabels[2], 50, 32);
    text(sectionLabels[1], 50, height - 50);
    text(sectionLabels[0], width/2 + 50, height - 50);
    text(sectionLabels[3], width/2 + 50, 32);
    
  } else {
    int size = height/10;
    feedbackbWidget.x = width/2;
    feedbackbWidget.y = height - size;
    feedbackbWidget.w = size;
    feedbackbWidget.h = size;
  }

  feedbackbWidget.update(sectionLikelihoods[0], 
    sectionLikelihoods[1], 
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

// update section likelihood value
public void updateLikelihood(int section, float value) {

  sectionLikelihoods[section] = value;
}