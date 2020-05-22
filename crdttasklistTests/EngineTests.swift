//
//  EngineTests.swift
//  crdttasklistTests
//
//  Created by Vladimir Shakhov on 6/29/19.
//  Copyright © 2019 Vladimir Shakhov. All rights reserved.
//
import XCTest

@testable import crdttasklist

enum MergeTestOp {
    case Merge(Int, Int)
    case Assert(Int, String)
    case AssertAll(String)
    case AssertMaxUndoSoFar(Int, UInt)
    case Edit(ei: Int, p: UInt, u: UInt, d: Delta<RopeInfo>)
}

struct MergeTestState {
    var peers: [Cow<Engine>]

    static func new(_ count: Int) -> MergeTestState {
        var peers:[Cow<Engine>] = []
        for i in 0..<count {
            var peer = Cow(Engine())
            peer.value.set_session_id(SessionId.from(((UInt64(i)*1000) as UInt64, UInt32(0))))
            peers.append(peer)
        }
        return MergeTestState(peers: peers)
    }

    mutating func run_op(_ op: MergeTestOp) {
        switch op {
        case .Merge(let ai, let bi):
            peers[ai].value.merge(peers[bi])
        case .Assert(let ei, let correct):
            assert(correct == self.peers[ei].value.get_head().to_string())
        case .AssertMaxUndoSoFar(let ei, let correct):
            assert(correct == self.peers[ei].value.max_undo_group_id())
        case .AssertAll(let correct):
            for (_, e) in self.peers.enumerated() {
                assert(correct == e.value.get_head().to_string())
            }
        case .Edit(let ei, let priority, let undo, let delta):
            let head = self.peers[ei].value.get_head_rev_id().token()
            self.peers[ei].value.edit_rev(priority, undo, head, delta)
        }
    }

    mutating func run_script(_ script: [MergeTestOp]) {
        for (i, op) in script.enumerated() {
            print("running \(op) at index \(i)")
            run_op(op)
        }
    }
}


class EngineTests: XCTestCase {

    let TEST_STR = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    func build_delta_1() -> Delta<RopeInfo> {
        var d_builder = DeltaBuilder<RopeInfo>(TEST_STR.len())
        d_builder.delete(Interval(10, 36))
        d_builder.replace(Interval(39, 42), Rope.from_str("DEEF"[...]))
        d_builder.replace(Interval(54, 54), Rope.from_str("999"[...]))
        d_builder.delete(Interval(58, 61))
        return d_builder.build()
    }

    func basic_rev(_ i: UInt) -> RevId {
        return RevId(session1: 1, session2: 0, num: UInt32(i))
    }


    func basic_insert_ops(_ inserts: [Subset], _ priority: UInt) -> [Revision] {
        return inserts.enumerated().map({ (i, inserts) in
            let ui = UInt(i)
            let deletes = Subset.make_empty(inserts.len())
            return Revision(
                rev_id: basic_rev(ui + 1),
                edit: .Edit(
                    priority: priority,
                    undo_group: ui + 1,
                    inserts: inserts,
                    deletes: deletes
                ),
                max_undo_so_far: ui + 1
            )
        })
    }

    func test_edit_rev_simple() {
        var engine = Engine.make_from_rope(Rope.from_str(TEST_STR[...]))
        let first_rev = engine.get_head_rev_id().token()
        engine.edit_rev(0, 1, first_rev, build_delta_1());
        XCTAssertEqual("0123456789abcDEEFghijklmnopqr999stuvz", String.from(rope: engine.get_head()))
    }

    func test_try_delta_rev_simple() {
        let str = "123456789"
        var engine = Engine.make_from_rope(Rope.from_str(str))
        let first_rev = engine.get_head_rev_id().token()
        var db = DeltaBuilder<RopeInfo>(str.len())
        db.delete(Interval(0, 8))
        let d = db.build()
        print("delta applied \(d.apply_to_string(str))")
        engine.edit_rev(1, 1, first_rev, d)
        XCTAssertEqual("9", engine.get_head().to_string())

        do {
            let d = try engine.try_delta_rev_head(first_rev).get()
            XCTAssertEqual(String.from(rope: engine.get_head()), d.apply_to_string(str))
        } catch {
            fatalError("should not happen")
        }
    }

    func test_try_delta_rev_head() {
        var engine = Engine.make_from_rope(Rope.from_str(TEST_STR))
        let first_rev = engine.get_head_rev_id().token()
        engine.edit_rev(1, 1, first_rev, build_delta_1())
        do {
            let d = try engine.try_delta_rev_head(first_rev).get()
            XCTAssertEqual(String.from(rope: engine.get_head()), d.apply_to_string(TEST_STR))
        } catch {
            fatalError("should not happen")
        }
    }

    func testCodeingDecoding() {
        let engine = Engine.make_from_rope(Rope.from_str(TEST_STR[...]))
        let fileEngine = saveThenLoad(obj: engine)
        XCTAssertEqual(engine, fileEngine)

    }

    func test_compute_transforms_1() {
        let inserts = TestHelpers.parse_subset_list("""
        -##-
        --#--
        ---#--
        #------
        """)
        let revs = basic_insert_ops(inserts, 1)

        let expand_by = compute_transforms(revs);
        XCTAssertEqual(1, expand_by.len())
        XCTAssertEqual(1, expand_by[0].0.priority)
        let subset_str = expand_by[0].1.dbg()
        XCTAssertEqual("#-####-", subset_str)
    }

    func test_compute_transforms_2() {
        let inserts_1 = TestHelpers.parse_subset_list("""
        -##-
        --#--
        """)
        var revs: [Revision] = basic_insert_ops(inserts_1, 1)
        let inserts_2 = TestHelpers.parse_subset_list("""
        ----
        """)
        let revs_2 = basic_insert_ops(inserts_2, 4)
        revs.append(contentsOf: revs_2)
        let inserts_3 = TestHelpers.parse_subset_list("""
        ---#--
        #------
        """)
        let revs_3 = basic_insert_ops(inserts_3, 2)
        revs.append(contentsOf: revs_3)

        let expand_by = compute_transforms(revs)
        XCTAssertEqual(2, expand_by.len())
        XCTAssertEqual(1, expand_by[0].0.priority);
        XCTAssertEqual(2, expand_by[1].0.priority);

        let subset_str = expand_by[0].1.dbg()
        XCTAssertEqual("-###-", subset_str)


        let subset_str_2 = (expand_by[1].1).dbg()
        XCTAssertEqual("#---#--", subset_str_2)
    }

    func test_compute_deltas_1() {
        let inserts = TestHelpers.parse_subset_list("""
        -##-
        --#--
        ---#--
        #------
        """)
        let revs = basic_insert_ops(inserts, 1);

        let text = Rope.from_str("13456")
        let tombstones = Rope.from_str("27")
        var deletes_from_union = TestHelpers.parse_subset("-#----#")
        let delta_ops = compute_deltas(revs, text, tombstones, deletes_from_union)

        print(delta_ops)

        var r = Rope.from_str("27");
        for op in delta_ops {
            r = op.inserts.apply(r)
        }
        XCTAssertEqual("1234567", String.from(rope: r))
    }

    func test_rebase_1() {
        let inserts = TestHelpers.parse_subset_list("""
        --#-
        ----#
        """)
        let a_revs = basic_insert_ops(Array(inserts), 1)
        let b_revs = basic_insert_ops(inserts, 2)

        let text_b = Rope.from_str("zpbj")
        let tombstones_b = Rope.from_str("a")
        var deletes_from_union_b = TestHelpers.parse_subset("-#---")
        let b_delta_ops = compute_deltas(b_revs, text_b, tombstones_b, deletes_from_union_b)

        print("\(b_delta_ops)")

        let text_a = Rope.from_str("zcbd")
        let tombstones_a = Rope.from_str("a")
        var deletes_from_union_a = TestHelpers.parse_subset("-#---")
        var expand_by = compute_transforms(a_revs)

        let (revs, text_2, tombstones_2, deletes_from_union_2) =
            rebase(&expand_by, b_delta_ops, text_a, tombstones_a, &deletes_from_union_a, 0)

        let rebased_inserts: [Subset] = revs.map({ c -> Subset in
            guard case .Edit(_, _, inserts: let inserts_, _) = c.edit else {
                 fatalError("not implemented")
            }
            return inserts_
        })

        TestHelpers.debug_subsets(rebased_inserts)
        let correct = TestHelpers.parse_subset_list("""
        ---#--
        ------#
        """)
        XCTAssertEqual(correct, rebased_inserts);


        XCTAssertEqual("zcpbdj", String.from(rope: text_2))
        XCTAssertEqual("a", String.from(rope: tombstones_2))
        XCTAssertEqual("-#-----", deletes_from_union_2.dbg())
    }

    func test_merge_insert_only_whiteboard() {
        let script: [MergeTestOp] = [
            .Edit(ei: 2, p: 1, u: 1, d: TestHelpers.parse_delta("ab")),
            .Merge(0, 2),
            .Merge(1, 2),
            .Assert(0, "ab"),
            .Assert(1, "ab"),
            .Assert(2, "ab"),
            .Edit(ei: 0, p: 3, u: 1, d: TestHelpers.parse_delta("-c-")),
            .Edit(ei: 0, p: 3, u: 1, d: TestHelpers.parse_delta("---d")),
            .Assert(0, "acbd"),
            .Edit(ei: 1, p: 5, u: 1, d: TestHelpers.parse_delta("-p-")),
            .Edit(ei: 1, p: 5, u: 1, d: TestHelpers.parse_delta("---j")),
            .Assert(1, "apbj"),
            .Edit(ei: 2, p: 1, u: 1, d: TestHelpers.parse_delta("z--")),
            .Merge(0,2),
            .Merge(1, 2),
            .Assert(0, "zacbd"),
            .Assert(1, "zapbj"),
            .Merge(0, 1),
            .Assert(0, "zacpbdj"),
        ]
        var state = MergeTestState.new(3)
        state.run_script(script)
    }
}
