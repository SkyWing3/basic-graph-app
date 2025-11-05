import 'dart:math';

class GeneticTspGeneration {
  const GeneticTspGeneration({
    required this.generation,
    required this.route,
    required this.bestDistance,
    required this.averageDistance,
  });

  final int generation;

  final List<String> route;

  final double bestDistance;

  final double averageDistance;
}

class GeneticTspSolver {
  GeneticTspSolver({
    required Map<String, Map<String, double>> adjacency,
    this.populationSize = 70,
    this.generations = 120,
    this.mutationRate = 0.18,
    this.elitismCount = 2,
    this.tournamentSize = 5,
    int? seed,
  }) : adjacency = _normalizeAdjacency(adjacency),
       _random = Random(seed) {
    if (this.adjacency.isEmpty) {
      throw ArgumentError('Adjacency map must contain at least one node.');
    }
    if (populationSize < 4) {
      throw ArgumentError.value(
        populationSize,
        'populationSize',
        'Must be at least 4',
      );
    }
    if (elitismCount < 0 || elitismCount > populationSize) {
      throw ArgumentError.value(
        elitismCount,
        'elitismCount',
        'Must be in the range [0, populationSize]',
      );
    }
    if (tournamentSize < 2 || tournamentSize > populationSize) {
      throw ArgumentError.value(
        tournamentSize,
        'tournamentSize',
        'Must be in the range [2, populationSize]',
      );
    }
  }

  final Map<String, Map<String, double>> adjacency;

  final int populationSize;

  final int generations;

  final double mutationRate;

  final int elitismCount;

  final int tournamentSize;

  final Random _random;

  Future<List<GeneticTspGeneration>> solve() async {
    final nodes = adjacency.keys.toList(growable: false);
    if (nodes.length < 3) {
      throw StateError('At least 3 nodes are required to solve the TSP.');
    }

    final startNode = nodes.first;
    final remainingNodes = nodes.sublist(1);
    final population = _initialPopulation(remainingNodes);
    var evaluations = _evaluatePopulation(population, startNode);

    final generationsLog = <GeneticTspGeneration>[
      _logGeneration(0, evaluations, startNode),
    ];

    var currentPopulation = population;

    for (var generation = 1; generation <= generations; generation++) {
      currentPopulation = _nextGeneration(evaluations);
      evaluations = _evaluatePopulation(currentPopulation, startNode);
      generationsLog.add(_logGeneration(generation, evaluations, startNode));
    }

    return generationsLog;
  }

  List<List<String>> _initialPopulation(List<String> remainingNodes) {
    if (remainingNodes.isEmpty) {
      return List.generate(populationSize, (_) => <String>[]);
    }

    final population = <List<String>>[];
    for (var i = 0; i < populationSize; i++) {
      final genome = List<String>.from(remainingNodes);
      genome.shuffle(_random);
      population.add(genome);
    }
    return population;
  }

  List<_ChromosomeEvaluation> _evaluatePopulation(
    List<List<String>> population,
    String startNode,
  ) {
    final evaluations = <_ChromosomeEvaluation>[];
    for (final genome in population) {
      final distance = _routeDistance(startNode, genome);
      evaluations.add(
        _ChromosomeEvaluation(genome: genome, distance: distance),
      );
    }

    evaluations.sort((a, b) => a.distance.compareTo(b.distance));
    return evaluations;
  }

  List<List<String>> _nextGeneration(List<_ChromosomeEvaluation> evaluations) {
    final nextPopulation = <List<String>>[];

    for (var i = 0; i < elitismCount && i < evaluations.length; i++) {
      nextPopulation.add(List<String>.from(evaluations[i].genome));
    }

    while (nextPopulation.length < populationSize) {
      final parent1 = _tournamentSelect(evaluations).genome;
      final parent2 = _tournamentSelect(evaluations).genome;
      var child = _orderedCrossover(parent1, parent2);
      if (_random.nextDouble() < mutationRate && child.length >= 2) {
        child = _swapMutation(child);
      }
      nextPopulation.add(child);
    }

    return nextPopulation;
  }

  GeneticTspGeneration _logGeneration(
    int generation,
    List<_ChromosomeEvaluation> evaluations,
    String startNode,
  ) {
    final best = evaluations.first;
    final average =
        evaluations.fold<double>(0, (sum, item) => sum + item.distance) /
        evaluations.length;

    return GeneticTspGeneration(
      generation: generation,
      route: _buildRoute(startNode, best.genome),
      bestDistance: best.distance,
      averageDistance: average,
    );
  }

  _ChromosomeEvaluation _tournamentSelect(
    List<_ChromosomeEvaluation> evaluations,
  ) {
    _ChromosomeEvaluation? best;
    for (var i = 0; i < tournamentSize; i++) {
      final candidate = evaluations[_random.nextInt(evaluations.length)];
      if (best == null || candidate.distance < best.distance) {
        best = candidate;
      }
    }
    return best!;
  }

  List<String> _orderedCrossover(List<String> parent1, List<String> parent2) {
    if (parent1.isEmpty || parent2.isEmpty) {
      return List<String>.from(parent1);
    }

    final length = parent1.length;
    final start = _random.nextInt(length);
    final end = start + 1 + _random.nextInt(length - start);

    final child = List<String?>.filled(length, null);
    final segment = <String>{};

    for (var i = start; i < end; i++) {
      child[i] = parent1[i];
      segment.add(parent1[i]);
    }

    var parent2Index = 0;
    for (var i = 0; i < length; i++) {
      if (child[i] != null) continue;

      while (segment.contains(parent2[parent2Index])) {
        parent2Index = (parent2Index + 1) % length;
      }

      child[i] = parent2[parent2Index];
      parent2Index = (parent2Index + 1) % length;
    }

    return List<String>.generate(length, (index) => child[index]!);
  }

  List<String> _swapMutation(List<String> genome) {
    final mutated = List<String>.from(genome);
    final indexA = _random.nextInt(mutated.length);
    var indexB = _random.nextInt(mutated.length);
    while (indexB == indexA) {
      indexB = _random.nextInt(mutated.length);
    }
    final temp = mutated[indexA];
    mutated[indexA] = mutated[indexB];
    mutated[indexB] = temp;
    return mutated;
  }

  List<String> _buildRoute(String startNode, List<String> genome) {
    return [startNode, ...genome, startNode];
  }

  double _routeDistance(String startNode, List<String> genome) {
    final route = _buildRoute(startNode, genome);
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final from = route[i];
      final to = route[i + 1];
      final weight = adjacency[from]?[to];
      if (weight == null) {
        return double.infinity;
      }
      total += weight;
    }
    return total;
  }

  static Map<String, Map<String, double>> _normalizeAdjacency(
    Map<String, Map<String, double>> input,
  ) {
    final normalized = <String, Map<String, double>>{};
    for (final entry in input.entries) {
      normalized.putIfAbsent(entry.key, () => <String, double>{});
      for (final target in entry.value.entries) {
        final current = normalized.putIfAbsent(
          target.key,
          () => <String, double>{},
        );
        normalized[entry.key]![target.key] = target.value;
        current[entry.key] = target.value;
      }
    }
    return normalized;
  }
}

class _ChromosomeEvaluation {
  const _ChromosomeEvaluation({required this.genome, required this.distance});

  final List<String> genome;
  final double distance;
}
