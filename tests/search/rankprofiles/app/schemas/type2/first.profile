rank-profile first {
    first-phase {
      expression: attribute(field23) * 10 + query(myvalue)
    }
    summary-features: attribute(field23) fieldMatch(field24).matches firstPhase query(myvalue)
}