import processing.video.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
Movie myMovie;

FeedbackWidget feedbackbWidget;

//Voix basse en mmmmmmm murmure chant avec bouche ferme;    de 0 - 2 min (si possible de laisser une trace de mmmmbackgound dans harmoniseur mais c est ce qui marche pour vous)

//rhythm avec voix saccadee rhytmique ou les mains qui se frappent l une contre l autre ou le tamtam d un bendir ; de 2- 6min21sec  (est ce possible puisque je ne l ai pas mentionne dans contrat?)

//Voix mi aigu/ aigu (par rapport au calibre de la voix de la personne qui chante) ;  6min26sec - 6min58 secondes
//Voix mi aigu/aigu  ; 10 minutes 04 secondes - 12 min 24 secondes 
//Voix mi aigu douce ,12min 25 -   14min 24 secondes

//rhythm avec bendir ou mains ou voix saccadee ; 14min 54 secondes - 17 min 39 secondes
//Voix grave douce; 17 min 46 secondes - 19 min 46 secondes


//~sectionLabels = [
//0: "LO freq - LO amp", 
//1: "HI freq - LO amp",
//2: "LO freq - HI amp",
//3: "HI freq - HI amp" ];


//int[] sections = { 0, 120, 386, 604, 745, 894, 1066}; 

float[] sectionStarts = { 1066, 745, 120, 386}; 
float[] sectionEnds = { 1186, 864, 381, 418}; 
float[] currentTimes = sectionStarts;
boolean[] playing = { false, false, false, false}; 
float[] sectionLikelihoods = {0, 0, 0, 0};

int sectionCount = 7;
int currentSection = -1;
int pitchSections = 3;
Movie[] movies;

PVector[] movieOrigins;

public void settings() {
  size(800, 600);
}


void setup() {
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 12000);
  oscP5.plug(this, "newSection", "/section");

  // widget size
  int size = height/10;
  feedbackbWidget = new FeedbackWidget(width/size + size, height - size, size, size);

  movies = new Movie[4];
  movieOrigins = new PVector[4];
  
  for (int i = 0; i<4; i++) {
    movies[i] = new Movie(this, "/Volumes/quartera/Dropbox/hammaniProject_media/video/hammani_motifsKabyles_codesSecretsFemmes.mp4");
    movies[i].noLoop();
  }
  
  movieOrigins[0] = new PVector(0, 0);
  movieOrigins[1] = new PVector(width/2, 0);
  movieOrigins[2] = new PVector(0, height/2);
  movieOrigins[3] = new PVector(width/2, height/2);
  
  
}

void draw() {
  clear();

  for (int i = 0; i<4; i++) {
    drawVideo(i);
  }  


  feedbackbWidget.update(sectionLikelihoods[0], 
    sectionLikelihoods[1], 
    sectionLikelihoods[2], 
    sectionLikelihoods[3]
    );
  feedbackbWidget.display();
}


void drawVideo(int i) {

  
  if (currentTimes[i] >= sectionEnds[i]) {
    currentTimes[i] = sectionStarts[i];
  }

  if (sectionLikelihoods[i] > 0.5) {
    if (!playing[i]) {
      movies[i].play();
      movies[i].jump(currentTimes[i]);
      playing[i] = true;
    } else {
      currentTimes[i] = movies[i].time();
    }
    
    tint(255, sectionLikelihoods[i]*255);
    image(movies[i], movieOrigins[i].x, movieOrigins[i].y, width/2, height/2);
    
  } else {
      movies[i].pause();
      playing[i] = false;
  }
}

// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}


// section change
public void newSection(int section, float value) {

  println("section " + str(section) + "  " + str(value));
  sectionLikelihoods[section] = value;

  //println("OSC SECTION INPUT " + str(section));
  // if (section > -1){
  //    myMovie.play();
  //   myMovie.jump(sections[section]);
  // } else {
  //   myMovie.stop();
  // }

  //println("OSC INPUT " + str(pitch));
  //int sectionToPlay = int(floor(pitch * pitchSections));
  //println("section to play " + str(sectionToPlay));
  //if (sectionToPlay != currentSection ){
  //   if (sectionToPlay < (sectionCount -1)){
  //      println("--------------------------- change section to play " + str(sectionToPlay));
  //      myMovie.play();
  //      myMovie.jump(sections[sectionToPlay]);
  //      currentSection = sectionToPlay;
  //   }
  //}
}