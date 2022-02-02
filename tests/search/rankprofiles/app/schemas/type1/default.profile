rank-profile default {
  first-phase {
    expression: attribute(field13) * 100
  }

  second-phase {
    expression: if (attribute(field13) > 90, attribute(field13) * attribute(field13), attribute(field13))
  }

  summary-features: attribute(field13)
}

