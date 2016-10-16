import java.io.*;
import java.util.*;
import java.util.function.Consumer;

class Board {
  
  static final float THERMOMETER_MIN = -2; // Minimum climate slider value
  static final float THERMOMETER_MAX = 2; // Maximum climate slider value
  static final float MIN_CREATURE_ENERGY = 1.2; // Minimum energy of newly added primordial creatures.
  static final float MAX_CREATURE_ENERGY = 2.0; // Maximum energy of newly added primordial creatures.
  static final float OBJECT_TIMESTEPS_PER_YEAR = 100;
  final color ROCK_COLOR = color(0, 0, 0.5);
  final color BACKGROUND_COLOR = color(0, 0, 0.1);
  static final float MINIMUM_SURVIVABLE_SIZE = 0.06; // The RADIUS (not energy) at which creatures die.
  static final float CREATURE_STROKE_WEIGHT = 0.6;
  
  final double FLASH_SPEED = 80;
  double MANUAL_BIRTH_SIZE = 1.2;
  final int creatureMinimumIncrement = 5;
  
  static final int POPULATION_HISTORY_LENGTH = 200;
  
  int boardWidth;
  int boardHeight;
  int creatureMinimum;   // Minimum number of creatures before more are added.
  
  float minTemperature;  // The lowest temperature reached during 'winter'
  float maxTemperature;  // The hottest temperature reached during 'summer'
  
  
  Tile[][] tiles;
  double year = 0; // The current date of the simulation
  
  ArrayList[][] softBodiesInPositions;
  ArrayList<Creature> creatures;
  Creature selectedCreature = null;
  int creatureIDUpTo = 0;
  final int LIST_SLOTS = 6;
  int creatureRankMetric = 0;
  color buttonColor = color(0.82, 0.8, 0.7);
  Creature[] list = new Creature[LIST_SLOTS];
  
  double temperature; // Current temperature of the world.
  
  double timeStep;
  
  int[] populationHistory;
  double recordPopulationEvery = 0.02;
  int playSpeed = 1;
  
  boolean draw = true;

  public Board(int w, int h, float stepSize, float min, float max, int cm, int SEED, String INITIAL_FILE_NAME, double ts) {
    noiseSeed(SEED);
    randomSeed(SEED);
    boardWidth = w;
    boardHeight = h;
    tiles = new Tile[w][h];
    for (int x = 0; x < boardWidth; x++) {
      for (int y = 0; y < boardHeight; y++) {
        float bigForce = pow(((float)y)/boardHeight, 0.5);
        float fertility = noise(x*stepSize*3, y*stepSize*3)*(1-bigForce)*5.0+noise(x*stepSize*0.5, y*stepSize*0.5)*bigForce*5.0-1.5;
        float climateType = noise(x*stepSize*0.2+10000, y*stepSize*0.2+10000)*1.63-0.4;
        climateType = min(max(climateType, 0), 0.8);
        tiles[x][y] = new Tile(x, y, fertility, 0, climateType, this);
      }
    }
    minTemperature = min;
    maxTemperature = max;

    softBodiesInPositions = new ArrayList[boardWidth][boardHeight];
    for (int x = 0; x < boardWidth; x++) {
      for (int y = 0; y < boardHeight; y++) {
        softBodiesInPositions[x][y] = new ArrayList<SoftBody>(0);
      }
    }

    creatureMinimum = cm;
    creatures = new ArrayList<Creature>(0);
    maintainCreatureMinimum(false);
    for (int i = 0; i < LIST_SLOTS; i++) {
      list[i] = null;
    }
    timeStep = ts;
    populationHistory = new int[POPULATION_HISTORY_LENGTH];
    for (int i = 0; i < POPULATION_HISTORY_LENGTH; i++) {
      populationHistory[i] = 0;
    }
  }
  public void drawBoard(float scaleUp, float camZoom, int mX, int mY) {
    if (!this.draw){
      return;
    }
    PerfTimer pt = new PerfTimer("board.drawBoard");
    for (int x = 0; x < boardWidth; x++) {
      for (int y = 0; y < boardHeight; y++) {
        tiles[x][y].drawTile(scaleUp, (mX == x && mY == y));
      }
    }
    for (int i = 0; i < creatures.size(); i++) {
      creatures.get(i).drawSoftBody(scaleUp, camZoom, true);
    }
    pt.end();
  }
  public void drawBlankBoard(float scaleUp) {
    fill(BACKGROUND_COLOR);
    rect(0, 0, scaleUp*boardWidth, scaleUp*boardHeight);
  }
  public void drawUI(float scaleUp, float camZoom, double timeStep, int x1, int y1, int x2, int y2, PFont font) {
    PerfTimer pt = new PerfTimer("board.drawUI");
    fill(0, 0, 0);
    noStroke();
    rect(x1, y1, x2-x1, y2-y1);

    pushMatrix();
    translate(x1, y1);

    fill(0, 0, 1);
    textAlign(RIGHT);
    text(nfs(camZoom*100, 0, 3)+" %", 0, y2-y1-30);
    textAlign(LEFT);
    textFont(font, 48);
    String yearText = "Year "+nf((float)year, 0, 2);
    text(yearText, 10, 48);
    float seasonTextXCoor = textWidth(yearText)+50;
    textFont(font, 24);
    text("Population: "+creatures.size(), 10, 80);
    String[] seasons = {"Winter", "Spring", "Summer", "Autumn"};
    text(seasons[(int)(getSeason()*4)] + "\nSeed: " + seed, seasonTextXCoor, 30);
    if (selectedCreature == null) {
      if (draw){
        for (int i = 0; i < LIST_SLOTS; i++) {
          list[i] = null;
        }
        for (int i = 0; i < creatures.size(); i++) {
          int lookingAt = 0;
          if (creatureRankMetric == 4) {
            while (lookingAt < LIST_SLOTS && list[lookingAt] != null && list[lookingAt].name.compareTo(creatures.get(i).name) < 0) {
              lookingAt++;
            }
          } else if (creatureRankMetric == 5) {
            while (lookingAt < LIST_SLOTS && list[lookingAt] != null && list[lookingAt].name.compareTo(creatures.get(i).name) >= 0) {
              lookingAt++;
            }
          } else {
            while (lookingAt < LIST_SLOTS && list[lookingAt] != null && list[lookingAt].measure(creatureRankMetric) > creatures.get(i).measure(creatureRankMetric)) {
              lookingAt++;
            }
          }
          if (lookingAt < LIST_SLOTS) {
            for (int j = LIST_SLOTS-1; j >= lookingAt+1; j--) {
              list[j] = list[j-1];
            }
            list[lookingAt] = creatures.get(i);
          }
        }
        double maxEnergy = 0;
        for (int i = 0; i < LIST_SLOTS; i++) {
          if (list[i] != null && list[i].energy > maxEnergy) {
            maxEnergy = list[i].energy;
          }
        }
        for (int i = 0; i < LIST_SLOTS; i++) {
          if (list[i] != null) {
            list[i].preferredRank += (i-list[i].preferredRank)*0.4;
            float y = y1+175+70*list[i].preferredRank;
            drawCreature(list[i], 45, y+5, 2.3, scaleUp);
            textFont(font, 24);
            textAlign(LEFT);
            noStroke();
            fill(0.333, 1, 0.4);
            float multi = (x2-x1-200);
            if (list[i].energy > 0) {
              rect(85, y+5, (float)(multi*list[i].energy/maxEnergy), 25);
            }
            if (list[i].energy > 1) {
              fill(0.333, 1, 0.8);
              rect(85+(float)(multi/maxEnergy), y+5, (float)(multi*(list[i].energy-1)/maxEnergy), 25);
            }
            fill(0, 0, 1);
            text(list[i].getCreatureName()+" ["+list[i].id+"] ("+toAge(list[i].birthTime)+")", 90, y);
            text("Energy: "+nf(100*(float)(list[i].energy), 0, 2), 90, y+25);
          }
        }
      }
      
      noStroke();
      fill(buttonColor);
      rect(10, 95, 220, 40);
      rect(240, 95, 220, 40);
      fill(0, 0, 1);
      textAlign(CENTER);
      text("Reset zoom", 120, 123);
      String[] sorts = {"Biggest", "Smallest", "Youngest", "Oldest", "A to Z", "Z to A", "Highest Gen", "Lowest Gen"};
      text("Sort by: "+sorts[creatureRankMetric], 350, 123);

      textFont(font, 19);
      String[] buttonTexts = {"Draw", "Maintain pop. at "+creatureMinimum, 
        "Old 1", "-   Old 1   +", 
        "Old 1", "-    Old 2    +", 
        "-    Play Speed ("+playSpeed+"x)    +", "This button does nothing"};
        
      for (int i = 0; i < 8; i++) {
        float x = (i%2)*230+10;
        float y = floor(i/2)*50+570;
        fill(buttonColor);
        rect(x, y, 220, 40);
        fill(0, 0, 1, 1);
        text(buttonTexts[i], x+110, y+17);
        if (i == 0) {
          
        } else if (i == 1) {
          text("-"+creatureMinimumIncrement+
            "                    +"+creatureMinimumIncrement, x+110, y+37);
        } else if (i <= 5) {
          text("Old File Save", x+110, y+37);
        }
      }
    } else {
      float energyUsage = (float)selectedCreature.getEnergyUsage(timeStep);
      noStroke();
      if (energyUsage <= 0) {
        fill(0, 1, 0.5);
      } else {
        fill(0.33, 1, 0.4);
      }
      float EUbar = 20*energyUsage;
      rect(110, 280, min(max(EUbar, -110), 110), 25);
      if (EUbar < -110) {
        rect(0, 280, 25, (-110-EUbar)*20+25);
      } else if (EUbar > 110) {
        float h = (EUbar-110)*20+25;
        rect(185, 280-h, 25, h);
      }
      fill(0, 0, 1);
      text("Name: "+selectedCreature.getCreatureName(), 10, 225);
      text("Energy: "+nf(100*(float)selectedCreature.energy, 0, 2)+" yums", 10, 250);
      text("E Change: "+nf(100*energyUsage, 0, 2)+" yums/year", 10, 275);

      text("ID: "+selectedCreature.id, 10, 325);
      text("X: "+nf((float)selectedCreature.px, 0, 2), 10, 350);
      text("Y: "+nf((float)selectedCreature.py, 0, 2), 10, 375);
      text("Rotation: "+nf((float)selectedCreature.rotation, 0, 2), 10, 400);
      text("B-day: "+toDate(selectedCreature.birthTime), 10, 425);
      text("("+toAge(selectedCreature.birthTime)+")", 10, 450);
      text("Generation: "+selectedCreature.gen, 10, 475);
      text("Parents: "+selectedCreature.parents, 10, 500, 210, 255);
      text("Hue: "+nf((float)(selectedCreature.hue), 0, 2), 10, 550, 210, 255);
      text("Mouth hue: "+nf((float)(selectedCreature.mouthHue), 0, 2), 10, 575, 210, 255);

      pushMatrix();
      translate(400, 80);
      float apX = round((mouseX-400-x1)/46.0);
      float apY = round((mouseY-80-y1)/46.0);
      selectedCreature.drawBrain(font, 46, (int)apX, (int)apY);
      popMatrix();
      
      
    }
    if (draw) drawPopulationGraph(x1, x2, y1, y2);
    
    fill(0, 0, 0);
    textAlign(RIGHT);
    textFont(font, 24);
    text("Population: "+creatures.size(), x2-x1-10, y2-y1-10);
    popMatrix();

    pushMatrix();
    translate(x2, y1);
    textAlign(RIGHT);
    textFont(font, 24);
    text("Temperature", -10, 24);
    if (draw) drawThermometer(-45, 30, 20, 660, temperature, THERMOMETER_MIN, THERMOMETER_MAX, color(0, 1, 1));
    popMatrix();

    if (selectedCreature != null) {
      drawCreature(selectedCreature, x1+65, y1+147, 2.3, scaleUp);
    }
    
    pt.end();
  }
  void drawPopulationGraph(float x1, float x2, float y1, float y2) {
    float barWidth = (x2-x1)/((float)(POPULATION_HISTORY_LENGTH));
    noStroke();
    fill(0.33333, 1, 0.6);
    int maxPopulation = 0;
    for (int i = 0; i < POPULATION_HISTORY_LENGTH; i++) {
      if (populationHistory[i] > maxPopulation) {
        maxPopulation = populationHistory[i];
      }
    }
    for (int i = 0; i < POPULATION_HISTORY_LENGTH; i++) {
      float h = (((float)populationHistory[i])/maxPopulation)*(y2-770);
      rect((POPULATION_HISTORY_LENGTH-1-i)*barWidth, y2-h, barWidth, h);
    }
  }
  public void iterate(final double timeStep) {
    PerfTimer pt = new PerfTimer("board.iterate");
    PerfTimer pt1 = pt.sub("popHistory");
    double prevYear = year;
    year += timeStep;
    if (Math.floor(year/recordPopulationEvery) != Math.floor(prevYear/recordPopulationEvery)) {
      for (int i = POPULATION_HISTORY_LENGTH-1; i >= 1; i--) {
        populationHistory[i] = populationHistory[i-1];
      }
      populationHistory[0] = creatures.size();
    }
    pt1.end();
    
    pt1 = pt.sub("tileGrowth");
    
    temperature = getGrowthRate(getSeason());
    double tempChangeIntoThisFrame = temperature-getGrowthRate(getSeason()-timeStep);
    double tempChangeOutOfThisFrame = getGrowthRate(getSeason()+timeStep)-temperature;
    if (tempChangeIntoThisFrame*tempChangeOutOfThisFrame <= 0) { // Temperature change flipped direction.
      for (int x = 0; x < boardWidth; x++) {
        for (int y = 0; y < boardHeight; y++) {
          tiles[x][y].iterate();
        }
      }
    }
    pt1.end();
    
    pt1 = pt.sub("prevEnergy");

    for (int i = 0; i < creatures.size(); i++) {
      creatures.get(i).setPreviousEnergy();
    }
    
    pt1.end();
    
    pt1 = pt.sub("maintainCreatureMinimum");
    maintainCreatureMinimum(false);
    pt1.end();
    
    pt1 = pt.sub("parallel_each");
    
    (new ArrayList<Creature>(this.creatures)).parallelStream().forEach(new Consumer<Creature>() {
      public void accept(Creature c){
        c.useBrain(timeStep, true);
        
        c.metabolize(timeStep);
      }
    });
    pt1.end();
    
    pt1 = pt.sub("perCreature");
    for (int i = 0; i < creatures.size(); i++) {
      Creature me = creatures.get(i);
      me.collide(timeStep);
      if (me.getRadius() < MINIMUM_SURVIVABLE_SIZE) {
        me.returnToEarth();
        creatures.remove(me);
        i--;
      }
    }
    pt1.end();
    finishIterate(timeStep);
    pt.end();
  }
  public void finishIterate(final double timeStep) {
    PerfTimer pt = new PerfTimer("board.finishIterate");
    
    for (Creature cr: this.creatures){
      cr.applyMotions(timeStep*OBJECT_TIMESTEPS_PER_YEAR);
    }
    
    PerfTimer pt1 = pt.sub("prox");
    
    Prox prox = new Prox();
    for (Creature cr : this.creatures){
      prox.add(cr.px, cr.py, cr);
    }
    
    pt1.end();
    
    final Prox proxFinal = prox;
    
    pt1 = pt.sub("parallel_seeing");
    this.creatures.parallelStream().forEach(new Consumer<Creature>(){
      public void accept(Creature c){
        c.see(timeStep*OBJECT_TIMESTEPS_PER_YEAR, proxFinal.get(c));
      }
    });
    pt1.end();
    
    
    pt.end();
  }
  private double getGrowthRate(double theTime) {
    double temperatureRange = maxTemperature-minTemperature;
    return minTemperature+temperatureRange*0.5-temperatureRange*0.5*Math.cos(theTime*2*Math.PI);
  }
  private double getGrowthOverTimeRange(double startTime, double endTime) {
    double temperatureRange = maxTemperature-minTemperature;
    double m = minTemperature+temperatureRange*0.5;
    return (endTime-startTime)*m+(temperatureRange/Math.PI/4.0)*
      (Math.sin(2*Math.PI*startTime)-Math.sin(2*Math.PI*endTime));
  }
  private double getSeason() {
    return (year%1.0);
  }
  private void drawThermometer(float x1, float y1, float w, float h, double prog, double min, double max, 
    color fillColor) {
    noStroke();
    fill(0, 0, 0.2);
    rect(x1, y1, w, h);
    fill(fillColor);
    double proportionFilled = (prog-min)/(max-min);
    rect(x1, (float)(y1+h*(1-proportionFilled)), w, (float)(proportionFilled*h));


    double zeroHeight = (0-min)/(max-min);
    double zeroLineY = y1+h*(1-zeroHeight);
    textAlign(RIGHT);
    stroke(0, 0, 1);
    strokeWeight(3);
    line(x1, (float)(zeroLineY), x1+w, (float)(zeroLineY));
    double minY = y1+h*(1-(minTemperature-min)/(max-min));
    double maxY = y1+h*(1-(maxTemperature-min)/(max-min));
    fill(0, 0, 0.8);
    line(x1, (float)(minY), x1+w*1.8, (float)(minY));
    line(x1, (float)(maxY), x1+w*1.8, (float)(maxY));
    line(x1+w*1.8, (float)(minY), x1+w*1.8, (float)(maxY));

    fill(0, 0, 1);
    text("Zero", x1-5, (float)(zeroLineY+8));
    text(nf(minTemperature, 0, 2), x1-5, (float)(minY+8));
    text(nf(maxTemperature, 0, 2), x1-5, (float)(maxY+8));
  }

  private boolean setMinTemperature(float temp) {
    minTemperature = tempBounds(THERMOMETER_MIN+temp*(THERMOMETER_MAX-THERMOMETER_MIN));
    if (minTemperature > maxTemperature) {
      float placeHolder = maxTemperature;
      maxTemperature = minTemperature;
      minTemperature = placeHolder;
      return true;
    }
    return false;
  }
  private boolean setMaxTemperature(float temp) {
    maxTemperature = tempBounds(THERMOMETER_MIN+temp*(THERMOMETER_MAX-THERMOMETER_MIN));
    if (minTemperature > maxTemperature) {
      float placeHolder = maxTemperature;
      maxTemperature = minTemperature;
      minTemperature = placeHolder;
      return true;
    }
    return false;
  }
  private float tempBounds(float temp) {
    return min(max(temp, THERMOMETER_MIN), THERMOMETER_MAX);
  }
  private float getHighTempProportion() {
    return (maxTemperature-THERMOMETER_MIN)/(THERMOMETER_MAX-THERMOMETER_MIN);
  }
  private float getLowTempProportion() {
    return (minTemperature-THERMOMETER_MIN)/(THERMOMETER_MAX-THERMOMETER_MIN);
  }
  private String toDate(double d) {
    return "Year "+nf((float)(d), 0, 2);
  }
  private String toAge(double d) {
    return nf((float)(year-d), 0, 2)+" yrs old";
  }
  private void maintainCreatureMinimum(boolean choosePreexisting) {
    while (creatures.size() < creatureMinimum) {
      if (choosePreexisting) {
        Creature c = getRandomCreature();
        c.addEnergy(Creature.SAFE_SIZE);
        c.reproduce(Creature.SAFE_SIZE, timeStep);
      } else {
        creatures.add(new Creature(random(0, boardWidth), random(0, boardHeight), 0, 0, 
          random(MIN_CREATURE_ENERGY, MAX_CREATURE_ENERGY), 1, random(0, 1), 1, 1, 
          this, year, random(0, 2*PI), 0, "", "[PRIMORDIAL]", true, null, null, 1, random(0, 1)));
      }
    }
  }
  private Creature getRandomCreature() {
    int index = (int)(random(0, creatures.size()));
    return creatures.get(index);
  }

  private void drawCreature(Creature c, float x, float y, float scale, float scaleUp) {
    pushMatrix();
    float scaleIconUp = scaleUp*scale;
    translate((float)(-c.px*scaleIconUp), (float)(-c.py*scaleIconUp));
    translate(x, y);
    c.drawSoftBody(scaleIconUp, 40.0/scale, false);
    popMatrix();
  }

  public void unselect() {
    selectedCreature = null;
  }
}