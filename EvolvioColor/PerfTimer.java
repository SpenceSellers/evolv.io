import java.util.*;


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
  
  private static Map<String, TimeData> times = new TreeMap();
  
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
  
  public PerfTimer sub(String name){
    return new PerfTimer(this.name + "." + name);
  }
  
  private void addEntry(long time){
    if (!PerfTimer.times.containsKey(this.name)){
      PerfTimer.times.put(this.name, new PerfTimer.TimeData());
    }
    
    PerfTimer.times.get(this.name).addEntry(time);
  }
  
  private static int getDepth(String name){
     return name.length() - name.replace(".", "").length();
  }
  
  private static String indent(int n){
    return new String(new char[n]).replace("\0", " ");
  }
  
  public static void printTimes(){
    System.out.println("Timings: ");
    for (Map.Entry entry : PerfTimer.times.entrySet()){
      TimeData data = (TimeData) entry.getValue();
      System.out.println(PerfTimer.indent(PerfTimer.getDepth((String) entry.getKey())) + entry.getKey() + ": " + data.sum * MS_IN_NS + " ms total, " + data.count + " calls, " + (data.sum / data.count) * MS_IN_NS + " ms avg.");
    }
  }
  
}