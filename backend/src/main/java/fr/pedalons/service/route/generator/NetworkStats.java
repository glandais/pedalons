package fr.pedalons.service.route.generator;

import java.util.Map;

/** Counters describing a built {@link NetworkGraph}. */
public record NetworkStats(
    int trackCount,
    int excludedTrackCount,
    int inputEdgeCount,
    int edgeCount,
    int nodeCount,
    double totalLengthM,
    int danglingStubCount,
    int maxSupport,
    int droppedInputEdges,
    int floatingObservations,
    int orphanPieces,
    int stitchedEdges,
    int selfLoopsDropped,
    int unknownSurfaceDetails,
    Map<TrackKind, Integer> liveTracksByKind) {}
