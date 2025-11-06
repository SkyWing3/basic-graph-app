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

    final population = _initialPopulation(nodes);
    var evaluations = _evaluatePopulation(population);
    if (evaluations.isEmpty) {
      throw StateError(
        'Las conexiones actuales no permiten construir un ciclo que visite todos los nodos.',
      );
    }

    final generationsLog = <GeneticTspGeneration>[
      _logGeneration(0, evaluations),
    ];

    var currentPopulation = population;

    for (var generation = 1; generation <= generations; generation++) {
      currentPopulation = _nextGeneration(evaluations);
      evaluations = _evaluatePopulation(currentPopulation);
      if (evaluations.isEmpty) {
        throw StateError(
          'Las conexiones actuales no permiten construir un ciclo que visite todos los nodos.',
        );
      }
      generationsLog.add(_logGeneration(generation, evaluations));
    }

    return generationsLog;
  }

  List<List<String>> _initialPopulation(List<String> nodes) {
    if (nodes.isEmpty) {
      return List.generate(populationSize, (_) => <String>[]);
    }

    final population = <List<String>>[];
    final attemptsLimit = max(populationSize * 20, 100);
    var attempts = 0;

    while (population.length < populationSize && attempts < attemptsLimit) {
      attempts++;
      final genome = List<String>.from(nodes);
      genome.shuffle(_random);
      if (_isValidGenome(genome)) {
        population.add(genome);
      }
    }

    if (population.isEmpty) {
      throw StateError(
        'No existe un ciclo válido usando únicamente las conexiones dibujadas.',
      );
    }

    while (population.length < populationSize) {
      population.add(
        List<String>.from(
          population[_random.nextInt(population.length)],
        ),
      );
    }
    return population;
  }

  List<_ChromosomeEvaluation> _evaluatePopulation(
    List<List<String>> population,
  ) {
    final evaluations = <_ChromosomeEvaluation>[];
    for (final genome in population) {
      final distance = _routeDistance(genome);
      if (!distance.isFinite) {
        continue;
      }
      evaluations.add(
        _ChromosomeEvaluation(genome: genome, distance: distance),
      );
    }

    evaluations.sort((a, b) => a.distance.compareTo(b.distance));
    return evaluations;
  }

  List<List<String>> _nextGeneration(
    List<_ChromosomeEvaluation> evaluations,
  ) {
    if (evaluations.isEmpty) {
      return const <List<String>>[];
    }

    final nextPopulation = <List<String>>[];

    for (var i = 0; i < elitismCount && i < evaluations.length; i++) {
      nextPopulation.add(List<String>.from(evaluations[i].genome));
    }

    while (nextPopulation.length < populationSize) {
      final parent1 = _tournamentSelect(evaluations).genome;
      final parent2 = _tournamentSelect(evaluations).genome;
      var child = _orderedCrossover(parent1, parent2);

      if (_random.nextDouble() < mutationRate) {
        child = _inversionMutation(child);
      }

      // Apply 2-opt local search to the child
      final improvedChild = _twoOptImprove(child);
      if (_isValidGenome(improvedChild)) {
        child = improvedChild;
      }

      if (!_isValidGenome(child)) {
        child = List<String>.from(
          evaluations[_random.nextInt(evaluations.length)].genome,
        );
      }

      nextPopulation.add(child);
    }

    return nextPopulation;
  }

  GeneticTspGeneration _logGeneration(
    int generation,
    List<_ChromosomeEvaluation> evaluations,
  ) {
    final best = evaluations.first;
    final average =
        evaluations.fold<double>(0, (sum, item) => sum + item.distance) /
        evaluations.length;

    return GeneticTspGeneration(
      generation: generation,
      route: _buildRoute(best.genome),
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
    if (length < 2) {
      return List<String>.from(parent1);
    }

    int start, end;
    start = _random.nextInt(length);
    end = _random.nextInt(length);
    while (end == start) {
      end = _random.nextInt(length);
    }

    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final segment = parent1.sublist(start, end);
    final child = List<String?>.filled(length, null);
    final segmentSet = Set<String>.from(segment);

    for (var i = 0; i < segment.length; i++) {
      child[start + i] = segment[i];
    }

    var childIndex = 0;
    for (var i = 0; i < length; i++) {
      final gene = parent2[i];
      if (!segmentSet.contains(gene)) {
        while (child[childIndex] != null) {
          childIndex++;
        }
        child[childIndex] = gene;
      }
    }

    return child.cast<String>().toList();
  }

  List<String> _inversionMutation(List<String> genome) {
    if (genome.length < 2) {
      return genome;
    }
    final mutated = List<String>.from(genome);
    int start, end;
    start = _random.nextInt(mutated.length);
    end = _random.nextInt(mutated.length);
    while (end == start) {
      end = _random.nextInt(mutated.length);
    }

    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final reversedSegment = mutated.sublist(start, end).reversed.toList();
    mutated.replaceRange(start, end, reversedSegment);
    return mutated;
  }

  List<String> _buildRoute(List<String> genome) {
    if (genome.isEmpty) {
      return const [];
    }
    final canonical = _canonicalizeGenome(genome);
    return [...canonical, canonical.first];
  }

  bool _isValidGenome(List<String> genome) {
    if (genome.isEmpty) {
      return false;
    }
    for (var i = 0; i < genome.length; i++) {
      final from = genome[i];
      final to = genome[(i + 1) % genome.length];
      final weight = adjacency[from]?[to];
      if (weight == null) {
        return false;
      }
    }
    return true;
  }

  double _routeDistance(List<String> genome) {
    if (genome.isEmpty) {
      return double.infinity;
    }
    var total = 0.0;
    for (var i = 0; i < genome.length; i++) {
      final from = genome[i];
      final to = genome[(i + 1) % genome.length];
      final weight = adjacency[from]?[to];
      if (weight == null) {
        return double.infinity;
      }
      total += weight;
    }
    return total;
  }

  List<String> _canonicalizeGenome(List<String> genome) {
    if (genome.isEmpty) {
      return genome;
    }
    final minNode = genome.reduce(
      (value, element) =>
          value.compareTo(element) <= 0 ? value : element,
    );
    final firstRotation = _rotateToFront(genome, genome.indexOf(minNode));
    final reversedGenome = List<String>.from(genome.reversed);
    final reversedIndex = reversedGenome.indexOf(minNode);
    final reversedRotation = _rotateToFront(reversedGenome, reversedIndex);

    final firstKey = firstRotation.join('\u0000');
    final secondKey = reversedRotation.join('\u0000');

    return firstKey.compareTo(secondKey) <= 0 ? firstRotation : reversedRotation;
  }

  List<String> _rotateToFront(List<String> genome, int index) {
    if (genome.isEmpty) {
      return const [];
    }
    final normalizedIndex = index <= 0
        ? 0
        : index >= genome.length
            ? genome.length - 1
            : index;
    if (normalizedIndex <= 0) {
      return List<String>.from(genome);
    }
    return [
      ...genome.sublist(normalizedIndex),
      ...genome.sublist(0, normalizedIndex),
    ];
  }

  // Lightweight 2-opt refinement that only swaps when the new edges exist.
  List<String> _twoOptImprove(List<String> genome) {
    if (genome.length < 4) {
      return List<String>.from(genome);
    }

    var candidate = List<String>.from(genome);
    var improved = true;

    while (improved) {
      improved = false;

      for (var i = 0; i < candidate.length - 1; i++) {
        final a = candidate[i];
        final b = candidate[(i + 1) % candidate.length];
        final ab = adjacency[a]?[b];
        if (ab == null) {
          continue;
        }

        for (var j = i + 2; j < candidate.length; j++) {
          if (i == 0 && j == candidate.length - 1) {
            continue;
          }
          final c = candidate[j];
          final d = candidate[(j + 1) % candidate.length];
          final cd = adjacency[c]?[d];
          if (cd == null) {
            continue;
          }

          final ac = adjacency[a]?[c];
          final bd = adjacency[b]?[d];
          if (ac == null || bd == null) {
            continue;
          }

          final currentDistance = ab + cd;
          final swappedDistance = ac + bd;
          if (swappedDistance + 1e-9 < currentDistance) {
            final reversedSegment =
                candidate.sublist(i + 1, j + 1).reversed.toList();
            candidate = [
              ...candidate.sublist(0, i + 1),
              ...reversedSegment,
              ...candidate.sublist(j + 1),
            ];
            improved = true;
            break;
          }
        }

        if (improved) {
          break;
        }
      }
    }

    return candidate;
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
