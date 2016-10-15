import java.util.TreeMap;
import java.util.Map;

class PerfTimer {
  private class TimeData {
    long sum;
    long count;
    
    TimeData() {
      this.sum = 0;
      this.count = 0;
    }
    
    void addEntry(long time){
      this.sum += time;
      this.count++;
    }
    
  }
  
  private static TreeMap<String, TimeData> times = new TreeMap();
  
  static final double MS_IN_NS = 1E-6;
  
  
  public String name;
  private long startTime;
  
  
  public PerfTimer(String name){
    this.name = name;
    this.startTime = System.nanoTime();
    
  }
  
  public void end(){
    
    long endTime = System.nanoTime();
    long time = endTime - this.startTime;
    this.addEntry(time);
  }
  
  private void addEntry(long time){
    if (!PerfTimer.times.containsKey(this.name)){
      PerfTimer.times.put(this.name, new PerfTimer.TimeData());
    }
    
    PerfTimer.times.get(this.name).addEntry(time);
  }
  
  public static void printTimes(){
    System.out.println("Timings: ");
    for (Map.Entry entry : PerfTimer.times.entrySet()){
      TimeData data = (TimeData) entry.getValue();
      System.out.println(entry.getKey() + ": " + data.sum * MS_IN_NS + " ms total, " + data.count + " calls, " + (data.sum / data.count) * MS_IN_NS + " ms avg.");
    }
  }
  
}