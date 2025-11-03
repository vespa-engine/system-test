rank-profile myvalue inherits default {

  inputs {
    query(myvalue): 5
  }

  rank-profile myInner inherits myvalue {
    inputs {
      query(myvalue): 7
    }

  }

}
