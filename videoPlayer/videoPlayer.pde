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

int[] sections = { 1066, 745, 120, 386}; 

int sectionCount = 7;
int currentSection = -1;
int pitchSections = 3;

public void settings() {
  size(800 , 300);
}


void setup() {
  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 12000);
  oscP5.plug(this, "newSection", "/section");
  int size = height/10;
  
  feedbackbWidget = new FeedbackWidget(width/size + size, height - size, size, size);


myMovie = new Movie(this, "/Volumes/quartera/Dropbox/hammaniProject_media/video/hammani_motifsKabyles_codesSecretsFemmes.mp4");
 // myMovie = new Movie(this, "/Users/bloit/Dropbox/hammaniProject_media/video/hammani_motifsKabyles_codesSecretsFemmes.mp4");

  myMovie.noLoop();
}

void draw() {
  clear();
  image(myMovie, 0, 0, width, height);
  feedbackbWidget.update();
  feedbackbWidget.display();
}

// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}


// section change
public void newSection(int section) {
  
 println("OSC SECTION INPUT " + str(section));
  if (section > -1){
     myMovie.play();
    myMovie.jump(sections[section]);
  } else {
    myMovie.stop();
  }
  
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