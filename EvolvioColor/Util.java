class Util {
  public static boolean isSane(double x){
    return !Double.isNaN(x) && !Double.isInfinite(x);
  }
}