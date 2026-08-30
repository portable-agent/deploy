package portable_agent.base

default ready := false

ready if {
  input.check == "ready"
}
