import java.util.*;
import java.util.Collections;

class Prox<T> {
  private class ProxData<T> {
    public double x;
    public double y;
    private Set<T> near = null;
    
    ProxData(double x, double y){
      this.x = x;
      this.y = y;
    }
    
    private void addNear(T t){
      if (this.near == null){
        this.near = new HashSet();
      }
      this.near.add(t);
    }
    
    public Set<T> getNear(){
      if (this.near != null){
        return this.near;
      } else {
        return Collections.EMPTY_SET;
      }
    }
  }
  
  private Map<T, ProxData<T>> map = new HashMap();
  
  public void add(double x, double y, T item){
    ProxData<T> ourProx = new ProxData(x, y);
    for (Map.Entry<T, ProxData<T>> e : this.map.entrySet()){
      double otherx = e.getValue().x;
      double othery = e.getValue().y;
      if (Math.abs(x - otherx) < 1.0 && Math.abs(y - othery) < 1.0){
        ourProx.addNear(e.getKey());
        e.getValue().addNear(item);
      }
    }
    
    this.map.put(item, ourProx);
  }
  
  
  public Set<T> get(T t){
    return this.map.get(t).getNear();
  }
}