class FeedbackWidget {

  int x, y, w, h;
  
  color c0 = color(255, 204, 0);
  color c1 = color(50, 55, 100);
  color c2 = color(150, 0, 30);
  color c3 = color(30, 140, 30);
  
  int [] alphas = {30, 100, 255, 30};
  
  FeedbackWidget(int _x, int _y, int _w, int _h){
    x = _x;
    y = _y;
    w = _w;
    h = _h;
  }
  
  void update(){
    
    
  }
  
  
  
  
  void display(){
    ellipseMode(CENTER);
    noFill();
    noStroke();
    ellipse(x, y, w, h);
    
    fill(c0, alphas[0]);
    arc(x, y, w, h, 0, PI/2);
    
    fill(c1, alphas[1]);
    arc(x, y, w, h, PI/2, PI);
    
    fill(c2, alphas[2]);
    arc(x, y, w, h, PI, 3*PI/2);
    
    fill(c3, alphas[3]);
    arc(x, y, w, h, 3*PI/2, PI*2);
    


  }
  
}