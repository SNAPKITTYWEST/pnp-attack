! P vs NP Attack: Heuristic Sweep
! Generates random 3-SAT near phase transition (ratio=4.26), tests 4 variable
! selection heuristics across 10000 instances, outputs one JSON line per heuristic.
! Compile: gfortran -O2 -o heuristic_sweep heuristic_sweep.f90 sat_solver.f90
! Usage:   ./heuristic_sweep | tee sweep_results.jsonl

program heuristic_sweep
    use sat_solver
    implicit none

    integer, parameter :: N_VARS       = 50
    integer, parameter :: N_CLAUSES    = 213   ! ratio 4.26 — phase transition
    integer, parameter :: N_INSTANCES  = 2500  ! per heuristic, 4x = 10000 total
    integer, parameter :: N_HEURISTICS = 4

    character(len=6), parameter :: HEUR_NAMES(N_HEURISTICS) = &
        ['random', 'moms  ', 'jw    ', 'vsids ']

    integer  :: h, inst_i, c, k, v, var
    logical  :: is_sat
    integer  :: sat_count, unsat_count

    type(sat_instance) :: inst
    type(assignment)   :: assign

    integer  :: lits(3), tried(3), ntried
    real     :: r
    logical  :: dup

    integer(kind=8) :: t0, t1, rate
    real(kind=8)    :: total_ms, avg_ms

    ! scores for MOMS/JW/VSIDS heuristics
    real    :: pos_score(N_VARS), neg_score(N_VARS)
    integer :: best_var
    real    :: best_score, s

    call system_clock(count_rate=rate)
    call random_seed()

    do h = 1, N_HEURISTICS
        sat_count   = 0
        unsat_count = 0
        total_ms    = 0.0d0

        do inst_i = 1, N_INSTANCES
            call init_sat(inst, N_VARS, N_CLAUSES)

            ! Generate random 3-SAT instance
            do c = 1, N_CLAUSES
                ntried = 0
                k      = 0
                do while (k < 3)
                    call random_number(r)
                    v = int(r * N_VARS) + 1
                    dup = .false.
                    do var = 1, ntried
                        if (tried(var) == v) then
                            dup = .true.
                            exit
                        end if
                    end do
                    if (.not. dup) then
                        k = k + 1
                        ntried = ntried + 1
                        tried(ntried) = v
                        call random_number(r)
                        if (r < 0.5) v = -v
                        lits(k) = v
                    end if
                end do
                call add_clause(inst, c, lits, 3)
            end do

            ! Heuristic-specific variable ordering via pre-scoring
            ! We inject heuristic bias by pre-assigning variable scores
            ! which influence the first unassigned variable picked in DPLL.
            ! For random: shuffle assignment order via seeded random.
            ! For MOMS/JW/VSIDS: score by clause frequency / size weighting.
            select case (h)
            case (1) ! random — no pre-scoring, DPLL picks first unassigned
                ! nothing to do

            case (2) ! MOMS: maximum occurrences in minimum size clauses
                pos_score = 0.0
                neg_score = 0.0
                do c = 1, inst%num_clauses
                    if (inst%clause_lengths(c) == 2) then
                        do k = 1, inst%clause_lengths(c)
                            v = inst%clauses(c, k)
                            if (v > 0) then
                                pos_score(v) = pos_score(v) + 1.0
                            else
                                neg_score(-v) = neg_score(-v) + 1.0
                            end if
                        end do
                    end if
                end do

            case (3) ! JW: Jeroslow-Wang scoring 2^{-|clause|}
                pos_score = 0.0
                neg_score = 0.0
                do c = 1, inst%num_clauses
                    s = 2.0 ** (-real(inst%clause_lengths(c)))
                    do k = 1, inst%clause_lengths(c)
                        v = inst%clauses(c, k)
                        if (v > 0) then
                            pos_score(v) = pos_score(v) + s
                        else
                            neg_score(-v) = neg_score(-v) + s
                        end if
                    end do
                end do

            case (4) ! VSIDS: unit clause frequency (simplified)
                pos_score = 0.0
                neg_score = 0.0
                do c = 1, inst%num_clauses
                    if (inst%clause_lengths(c) == 1) then
                        v = inst%clauses(c, 1)
                        if (v > 0) then
                            pos_score(v) = pos_score(v) + 1.0
                        else
                            neg_score(-v) = neg_score(-v) + 1.0
                        end if
                    end if
                end do
            end select

            ! For scored heuristics: bias the initial assignment order
            ! by pre-setting the highest-score variable first.
            if (h >= 2) then
                best_var   = 0
                best_score = -1.0
                do var = 1, N_VARS
                    s = pos_score(var) + neg_score(var)
                    if (s > best_score) then
                        best_score = s
                        best_var   = var
                    end if
                end do
                ! Pre-assign best variable to try true first (DPLL will backtrack if needed)
                if (best_var > 0) then
                    call init_assignment(assign, N_VARS)
                    assign%values(best_var) = 1
                end if
            end if

            call system_clock(t0)
            call solve_sat(inst, assign, is_sat)
            call system_clock(t1)

            total_ms = total_ms + real(t1 - t0, kind=8) / real(rate, kind=8) * 1000.0d0

            if (is_sat) then
                sat_count = sat_count + 1
            else
                unsat_count = unsat_count + 1
            end if
        end do

        avg_ms = total_ms / real(N_INSTANCES, kind=8)

        ! Output JSON line — one per heuristic
        write(*,'(A,A,A,I0,A,I0,A,F8.4,A)') &
            '{"heuristic":"', trim(HEUR_NAMES(h)), &
            '","sat_count":', sat_count, &
            ',"unsat_count":', unsat_count, &
            ',"avg_ms":', avg_ms, '}'
    end do

end program heuristic_sweep
