import java.util.*;

class Prox<T> {
  private class ProxData<T> {
    public double x;
    public double y;
    public Set<T> near;
    
    ProxData(double x, double y, Set<T> near){
      this.x = x;
      this.y = y;
      this.near = near;
    }
  }
  
  private Map<T, ProxData<T>> map = new HashMap();
  
  public void add(double x, double y, T item){
    Set<T> nearUs = new HashSet();
    for (Map.Entry<T, ProxData<T>> e : this.map.entrySet()){
      double otherx = e.getValue().x;
      double othery = e.getValue().y;
      if (Math.abs(x - otherx) < 1.0 && Math.abs(y - othery) < 1.0){
        nearUs.add(e.getKey());
        e.getValue().near.add(item);
      }
    }
    
    this.map.put(item, new ProxData(x, y, nearUs));
  }
  
  //private void addEmpty(T t){
  //  this.map.put(t, new TreeSet());
  //}
  
  public Set<T> get(T t){
    return this.map.get(t).near;
  }
}