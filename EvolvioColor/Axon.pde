class Axon {
  static final double MUTABILITY_MUTABILITY = 0.7;
  static final int MUTATE_POWER = 9;
  final double mutate_multi;

  double weight;
  double mutability;
  public Axon(double w, double m) {
    weight = w;
    mutability = m;
    mutate_multi = Math.pow(0.5, MUTATE_POWER);
  }

  public Axon mutateAxon() {
    double mutabilityMutate = Math.pow(0.5, pmRan()*MUTABILITY_MUTABILITY);
    return new Axon(weight+r()*mutability/mutate_multi, mutability*mutabilityMutate);
  }
  public double r() {
    return Math.pow(pmRan(), MUTATE_POWER);
  }
  public double pmRan() {
    return Math.random()*2-1;
  }
}