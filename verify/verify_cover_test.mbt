// verify 包证明函数的可执行投影（每个证明函数在合法前置下的真值表；证明义务由 moon prove 机器可查）

///|
test "clamp_i64 covers all three branches" {
  assert_eq(@verify.clamp_i64(5L, 1L, 10L), 5L)
  assert_eq(@verify.clamp_i64(0L, 1L, 10L), 1L)
  assert_eq(@verify.clamp_i64(11L, 1L, 10L), 10L)
  assert_eq(@verify.clamp_i64(1L, 1L, 10L), 1L)
  assert_eq(@verify.clamp_i64(10L, 1L, 10L), 10L)
}

///|
test "next_seq and inbox_advance match their specifications" {
  assert_eq(@verify.next_seq(41L), 42L)
  assert_true(@verify.next_seq(0L) > 0L)
  assert_true(@verify.inbox_advance(3L, 4L))
  assert_false(@verify.inbox_advance(3L, 3L))
  assert_false(@verify.inbox_advance(3L, 2L))
}

///|
test "composition proofs hold on sampled inputs" {
  assert_true(@verify.clamp_keeps_above(0L, 5L, 2L, 9L))
  assert_true(@verify.replay_chain(1L, 2L, 3L))
  assert_eq(@verify.gen_seq(10L, 0L), 11L)
  assert_eq(@verify.gen_seq(10L, 4L), 15L)
  assert_true(@verify.gen_seq_advances(10L, 7L))
  assert_true(@verify.gen_seq_strict(10L, 7L))
}

///|
test "ATR state machine core model" {
  assert_eq(@verify.STATE_PENDING, 0)
  assert_eq(@verify.STATE_ACTIVE, 1)
  assert_eq(@verify.activation_after2(@verify.STATE_PENDING, true), 1)
  assert_eq(@verify.activation_after2(@verify.STATE_PENDING, false), 0)
  assert_true(@verify.dispatch_allowed(@verify.STATE_ACTIVE))
  assert_false(@verify.dispatch_allowed(@verify.STATE_PENDING))
  assert_true(@verify.register_accepts_enables_dispatch())
  assert_false(@verify.unregistered_dispatch_denied())
}

///|
test "inbox invariants and cross-machine composition" {
  assert_eq(@verify.inbox_update(3L, 9L, true), 9L)
  assert_eq(@verify.inbox_update(3L, 2L, false), 3L)
  assert_true(@verify.inbox_monotonic(3L, 9L, true))
  assert_true(@verify.inbox_monotonic(3L, 2L, false))
  assert_true(@verify.dispatch_seq_admitted_by_peer(5L, 5L))
  assert_true(@verify.dispatch_seq_admitted_by_peer(5L, 0L))
}

///|
test "capacity and JS safe-domain guards" {
  assert_eq(@verify.after_register(0), 1)
  assert_true(@verify.register_within_capacity(9, 10))
  assert_eq(@verify.JS_SAFE_BOUND, 9007199254740992L)
  assert_true(@verify.in_js_safe_domain(0L))
  assert_true(@verify.in_js_safe_domain(@verify.JS_SAFE_BOUND - 1L))
  assert_false(@verify.in_js_safe_domain(@verify.JS_SAFE_BOUND))
  assert_true(@verify.safe_domain_no_overflow(1000L))
  assert_true(@verify.aic_alloc_guard(100L, 999999L))
}
