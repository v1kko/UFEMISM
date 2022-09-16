MODULE petsc_module

  ! Contains routines that use the PETSc matrix solvers
  !
  ! Convention: xx = Fortran, x = PETSc
  
#include <petsc/finclude/petscksp.h>
  USE petscksp
  USE mpi
  use mpi_module,                      only: allgather_array
  USE parallel_module,                 ONLY: par, sync, cerr, ierr, partition_list
  USE configuration_module,            ONLY: dp, C, routine_path, init_routine, finalise_routine, crash, warning
  USE data_types_module,               ONLY: type_sparse_matrix_CSR_dp

  IMPLICIT NONE

  INTEGER :: perr    ! Error flag for PETSc routines

#if (PETSC_VERSION_RELEASE == 1)
#if (PETSC_VERSION_MAJOR == 3 && PETSC_VERSION_MINOR == 15)
  ! Some interfaces are not autogenerated in petsc 3.15 (snellius, ubuntu), provide them here to avoid implicit calls
  interface
    subroutine VecDestroy( vec, err)
      import
      type(tVec) :: vec
      integer    :: err
    end subroutine
    subroutine KspDestroy( ksp, err)
      import
      type(tKSP) :: ksp
      integer    :: err
    end subroutine
    subroutine MatDestroy( mat, err)
      import
      type(tMat) :: mat
      integer    :: err
    end subroutine
  end interface
#endif
#endif

CONTAINS
  
! == Solve a square CSR matrix equation with PETSc
  SUBROUTINE solve_matrix_equation_CSR_PETSc( A_CSR, bb, xx, rtol, abstol)
      
    IMPLICIT NONE
    
    ! In/output variables:
    TYPE(type_sparse_matrix_CSR_dp),     INTENT(IN)    :: A_CSR
    REAL(dp), DIMENSION(:    ),          INTENT(IN)    :: bb
    REAL(dp), DIMENSION(:    ),          INTENT(INOUT) :: xx
    REAL(dp),                            INTENT(IN)    :: rtol, abstol
    
    ! Local variables
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'solve_matrix_equation_CSR_PETSc'
    TYPE(tMat)                                         :: A
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Convert matrix to PETSc format
    CALL mat_CSR2petsc( A_CSR, A)
    
    ! Solve the PETSC matrix equation
    CALL solve_matrix_equation_PETSc( A, bb, xx, rtol, abstol)
    
    ! Clean up after yourself
    CALL MatDestroy( A, perr)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE solve_matrix_equation_CSR_PETSc
  SUBROUTINE solve_matrix_equation_PETSc( A, bb, xx, rtol, abstol)
    ! Solve the matrix equation using a Krylov solver from PETSc
      
    IMPLICIT NONE
    
    ! In/output variables:
    TYPE(tMat),                          INTENT(IN)    :: A
    REAL(dp), DIMENSION(:    ),          INTENT(IN)    :: bb
    REAL(dp), DIMENSION(:    ),          INTENT(INOUT) :: xx
    REAL(dp),                            INTENT(IN)    :: rtol, abstol
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'solve_matrix_equation_PETSc'
    INTEGER                                            :: m, n, n1, n2, m1, m2
    TYPE(tVec)                                         :: b
    TYPE(tVec)                                         :: x
    TYPE(tKSP)                                         :: KSP_solver
    INTEGER                                            :: its
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Safety
    CALL MatGetSize( A, m, n, perr)
    call partition_list(m, par%i, par%n, m1, m2)
    call partition_list(n, par%i, par%n, n1, n2)
    
    IF (n2-n1+1 /= SIZE( xx,1) .OR. m2-m1+1 /= SIZE( bb,1)) THEN
      CALL crash('matrix and vector sub-sizes dont match!')
    END IF
    
  ! == Set up right-hand side and solution vectors as PETSc data structures
  ! =======================================================================
    
    CALL vec_double2petsc( xx, x, n)
    CALL vec_double2petsc( bb, b, m)
    
  ! Set up the solver
  ! =================
    
    ! Set up the KSP solver
    CALL KSPcreate( PETSC_COMM_WORLD, KSP_solver, perr)
  
    ! Set operators. Here the matrix that defines the linear system
    ! also serves as the preconditioning matrix.
    CALL KSPSetOperators( KSP_solver, A, A, perr)

    ! Iterative solver tolerances
    CALL KSPSetTolerances( KSP_solver, rtol, abstol, PETSC_DEFAULT_REAL, PETSC_DEFAULT_INTEGER, perr)
    
    ! Set runtime options, e.g.,
    !     -ksp_type <type> -pc_type <type> -ksp_monitor -ksp_rtol <rtol>
    ! These options will override those specified above as long as
    ! KSPSetFromOptions() is called _after_ any other customization routines.
    CALL KSPSetFromOptions( KSP_solver, perr)
    
  ! == Solve Ax=b
  ! =============
    
    ! Solve the linear system
    CALL KSPSolve( KSP_solver, b, x, perr)
  
    ! Find out how many iterations it took
    CALL KSPGetIterationNumber( KSP_solver, its, perr)
    !IF (par%master) WRITE(0,*) '   PETSc solved Ax=b in ', its, ' iterations'
    
    ! Get the solution back to the native UFEMISM storage structure
    CALL vec_petsc2double( x, xx)
    
    ! Clean up after yourself
    CALL KSPDestroy( KSP_solver, perr)
    CALL VecDestroy( x, perr)
    CALL VecDestroy( b, perr)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE solve_matrix_equation_PETSc
  
! == Conversion between 1-D Fortran double-precision arrays and PETSc parallel vectors
  SUBROUTINE vec_double2petsc( xx, x, n)
    ! Convert a regular 1-D Fortran double-precision array to a PETSc parallel vector
      
    IMPLICIT NONE
    
    ! In- and output variables:
    REAL(dp), DIMENSION(:    ),          INTENT(IN)    :: xx
    TYPE(tVec),                          INTENT(INOUT) :: x
    integer,                             intent(in)    :: n
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'vec_double2petsc'
    TYPE(PetscInt)                                     :: istart,iend,i
    
    ! Add routine to path
    CALL init_routine( routine_name)

    ! Create parallel vector
    CALL VecCreate( PETSC_COMM_WORLD, x, perr)
    CALL VecSetSizes( x, PETSC_DECIDE, n, perr)
    CALL VecSetFromOptions( x, perr)
    
    ! Get parallelisation domains ("ownership ranges")
    CALL VecGetOwnershipRange( x, istart, iend, perr)
    
    ! Fill in vector values
    DO i = istart+1,iend ! +1 because PETSc indexes from 0
      CALL VecSetValues( x, 1, i-1, xx( i-istart ), INSERT_VALUES, perr)
    END DO
    CALL sync
    
    ! Assemble vectors, using the 2-step process:
    !   VecAssemblyBegin(), VecAssemblyEnd()
    ! Computations can be done while messages are in transition
    ! by placing code between these two statements.
    
    CALL VecAssemblyBegin( x, perr)
    CALL VecAssemblyEnd(   x, perr)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE vec_double2petsc
  SUBROUTINE vec_petsc2double( x, xx)
    ! Convert a PETSc parallel vector to a regular 1-D Fortran double-precision array
      
    IMPLICIT NONE
    
    ! In- and output variables:
    TYPE(tVec),                          INTENT(IN)    :: x
    REAL(dp), DIMENSION(:    ),          INTENT(OUT)   :: xx
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'vec_petsc2double'
    TYPE(PetscInt)                                     :: istart,iend,i,n
    TYPE(PetscInt),    DIMENSION(1)                    :: ix
    TYPE(PetscScalar), DIMENSION(1)                    :: v
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Safety
    CALL VecGetSize( x, n, perr)

    ! Get parallelisation domains ("ownership ranges")
    CALL VecGetOwnershipRange( x, istart, iend, perr)

    IF (iend-istart /= size(xx,1)) THEN
      CALL crash('Fortran and PETSc vector sizes dont match!')
    END IF
    
    
    ! Get values
    DO i = istart+1,iend
      ix(1) = i-1
      CALL VecGetValues( x, 1, ix, v, perr)
      xx( i-istart) = v(1)
    END DO
    CALL sync

    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE vec_petsc2double
  SUBROUTINE mat_petsc2CSR( A, A_CSR)
    ! Convert a PETSC parallel matrix to a CSR-format matrix in regular Fortran arrays
      
    IMPLICIT NONE
    
    ! In/output variables:
    TYPE(tMat),                          INTENT(IN)    :: A
    TYPE(type_sparse_matrix_CSR_dp),     INTENT(OUT)   :: A_CSR
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'mat_petsc2CSR'
    INTEGER                                            :: m, n, istart, iend, i
    INTEGER                                            :: ncols, nnz
    INTEGER,  DIMENSION(:    ), ALLOCATABLE            :: cols
    REAL(dp), DIMENSION(:    ), ALLOCATABLE            :: vals
    INTEGER,  DIMENSION(:    ), allocatable            ::  nnz_rows
    INTEGER                                            :: wnnz_rows
    INTEGER                                            :: k1, k2
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! First get the number of rows and columns
    CALL MatGetSize( A, m, n, perr)
    
    ! Find number of non-zeros per row
    allocate( nnz_rows( m))
    
    CALL MatGetOwnershipRange( A, istart, iend, perr)
    
    ALLOCATE( cols( n))
    ALLOCATE( vals( n))
    
    DO i = istart+1, iend ! +1 because PETSc indexes from 0
      CALL MatGetRow( A, i-1, ncols, cols, vals, perr)
      nnz_rows( i) = ncols
      CALL MatRestoreRow( A, i-1, ncols, cols, vals, perr)
    END DO
   
    call allgather_array(nnz_rows) 
    ! Find the number of non-zeros
    nnz = SUM( nnz_rows)
    
    ! Allocate memory for the CSR matrix
    A_CSR%m       = m
    A_CSR%n       = n
    A_CSR%nnz_max = nnz
    A_CSR%nnz     = nnz
    
    allocate( A_CSR%ptr( A_CSR%m+1 ) )
    allocate( A_CSR%index (A_CSR%nnz))
    allocate( A_CSR%val(   A_CSR%nnz))
    
    ! Fill in the ptr array
    A_CSR%ptr( 1) = 1
    DO i = 2, m+1
      A_CSR%ptr( i) = A_CSR%ptr( i-1) + nnz_rows( i-1)
    END DO
    
    ! Copy data from the PETSc matrix to the CSR arrays
    DO i = istart+1, iend ! +1 because PETSc indexes from 0
      k1 = A_CSR%ptr( i)
      k2 = A_CSR%ptr( i+1) - 1
      CALL MatGetRow( A, i-1, ncols, cols, vals, perr)
      A_CSR%index( k1:k2) = cols( 1:ncols)+1
      A_CSR%val(   k1:k2) = vals( 1:ncols)
      CALL MatRestoreRow( A, i-1, ncols, cols, vals, perr)
    END DO
    
    !Make matrix available on all cores
    call allgather_array(A_CSR%index,A_CSR%ptr(istart+1),A_CSR%ptr(iend+1) -1) 
    call allgather_array(A_CSR%val  ,A_CSR%ptr(istart+1),A_CSR%ptr(iend+1) -1) 

    ! Clean up after yourself
    deallocate( nnz_rows)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name, n_extra_windows_expected = 7)
    
  END SUBROUTINE mat_petsc2CSR
  SUBROUTINE mat_CSR2petsc( A_CSR, A)
    ! Convert a CSR-format matrix in regular Fortran arrays to a PETSC parallel matrix
    !
    ! NOTE: the PETSc documentation seems to advise against using the MatCreateMPIAIJWithArrays
    !       routine used here. However, for the advised way of using MatSetValues with preallocation
    !       I've not been able to find a way that is fast enough to be useful without having to
    !       preallocate -WAY- too much memory. Especially for the remapping matrices, which
    !       can have hundreds or even thousands of non-zero elements per row, this can make the
    !       model run hella slow, whereas the current solution seems to work perfectly. So there you go.
      
    IMPLICIT NONE
    
    ! In/output variables:
    TYPE(type_sparse_matrix_CSR_dp),     INTENT(IN)    :: A_CSR
    TYPE(tMat),                          INTENT(OUT)   :: A
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'mat_CSR2petsc'
    INTEGER                                            :: i1, i2, nrows_proc, nrows_scan, i, k1, k2, nnz_row, nnz_proc, ii, k, kk
    INTEGER,  DIMENSION(:    ), ALLOCATABLE            :: ptr_proc, index_proc
    REAL(dp), DIMENSION(:    ), ALLOCATABLE            :: val_proc
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Determine process domains
    ! NOTE: slightly different from how it's done in partition_list, this is needed
    !       because otherwise PETSc will occasionally throw errors because the 
    !       process domains are different from what it expects.
    nrows_proc = PETSC_DECIDE
    CALL PetscSplitOwnership( PETSC_COMM_WORLD, nrows_proc, A_CSR%m, perr)
    CALL MPI_Scan( nrows_proc, nrows_scan, 1, MPI_INTEGER, MPI_SUM, PETSC_COMM_WORLD, ierr)
    i1 = nrows_scan + 1 - nrows_proc
    i2 = i1 + nrows_proc - 1
    
    ! Determine number of non-zeros for this process
    nnz_proc = 0
    DO i = i1, i2
      k1 = A_CSR%ptr( i)
      k2 = A_CSR%ptr( i+1) - 1
      nnz_row = k2 + 1 - k1
      nnz_proc = nnz_proc + nnz_row
    END DO
    CALL sync
    
    ! Allocate memory for local CSR-submatrix
    ALLOCATE( ptr_proc(   0:nrows_proc    ))
    ALLOCATE( index_proc( 0:nnz_proc   - 1))
    ALLOCATE( val_proc(   0:nnz_proc   - 1))
    
    ! Copy matrix data
    DO i = i1, i2
    
      ! ptr
      ii = i - i1
      ptr_proc( ii) = A_CSR%ptr( i) - A_CSR%ptr( i1)
      
      ! index and val
      k1 = A_CSR%ptr( i)
      k2 = A_CSR%ptr( i+1) - 1
      DO k = k1, k2
        kk = k - A_CSR%ptr( i1)
        index_proc( kk) = A_CSR%index( k) - 1
        val_proc(   kk) = A_CSR%val(   k)
      END DO
      
    END DO
    ! Last row
    ptr_proc( nrows_proc) = A_CSR%ptr( i2+1) - A_CSR%ptr( i1)
    
    ! Create PETSc matrix
    CALL MatCreateMPIAIJWithArrays( PETSC_COMM_WORLD, nrows_proc, PETSC_DECIDE, PETSC_DETERMINE, A_CSR%n, ptr_proc, index_proc, val_proc, A, perr)
    
    ! Assemble matrix and vectors, using the 2-step process:
    !   MatAssemblyBegin(), MatAssemblyEnd()
    ! Computations can be done while messages are in transition
    ! by placing code between these two statements.
    
    CALL MatAssemblyBegin( A, MAT_FINAL_ASSEMBLY, perr)
    CALL MatAssemblyEnd(   A, MAT_FINAL_ASSEMBLY, perr)
    
    ! Clean up after yourself
    DEALLOCATE( ptr_proc  )
    DEALLOCATE( index_proc)
    DEALLOCATE( val_proc  )
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE mat_CSR2petsc
  
! == Matrix-vector multiplication
  SUBROUTINE multiply_PETSc_matrix_with_vector_1D( A, xx, yy)
    ! Multiply a PETSc matrix with a FORTRAN vector: y = A*x
      
    IMPLICIT NONE
    
    ! In- and output variables:
    TYPE(tMat),                          INTENT(IN)    :: A
    REAL(dp), DIMENSION(:    ), target,  INTENT(IN)    :: xx
    REAL(dp), DIMENSION(:    ), target,  INTENT(OUT)   :: yy
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'multiply_PETSc_matrix_with_vector_1D'
    TYPE(PetscInt)                                     :: m, n
    TYPE(tVec)                                         :: x, y
    integer                                            :: m1, m2, n1, n2
    real(dp), dimension(:    ), pointer                :: xxp, yyp
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Safety
    CALL MatGetSize( A, m, n, perr)
    call partition_list(m, par%i, par%n, m1, m2)
    call partition_list(n, par%i, par%n, n1, n2)
    
    IF (n2-n1+1 /= SIZE( xx,1) .OR. m2-m1+1 /= SIZE( yy,1)) THEN
      CALL crash('matrix and vector sub-sizes dont match!')
    END IF

    xxp(n1:n2) => xx
    yyp(m1:m2) => yy

    ! Convert Fortran array xx to PETSc vector x
    CALL vec_double2petsc( xxp, x, n)
    
    ! Set up PETSc vector y for the answer
    CALL VecCreate( PETSC_COMM_WORLD, y, perr)
    CALL VecSetSizes( y, PETSC_DECIDE, m, perr)
    CALL VecSetFromOptions( y, perr)
    
    ! Compute the matrix-vector product
    CALL MatMult( A, x, y, perr)
    
    ! Convert PETSc vector y to Fortran array yy
    CALL vec_petsc2double( y, yy)
    
    ! Clean up after yourself
    CALL VecDestroy( x, perr)
    CALL VecDestroy( y, perr)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE multiply_PETSc_matrix_with_vector_1D
  SUBROUTINE multiply_PETSc_matrix_with_vector_2D( A, xx, yy)
    ! Multiply a PETSc matrix with a FORTRAN vector: y = A*x
      
    IMPLICIT NONE
    
    ! In- and output variables:
    TYPE(tMat),                          INTENT(IN)    :: A
    REAL(dp), DIMENSION(:,:  ),          INTENT(IN)    :: xx
    REAL(dp), DIMENSION(:,:  ),          INTENT(OUT)   :: yy
    
    ! Local variables:
    CHARACTER(LEN=256), PARAMETER                      :: routine_name = 'multiply_PETSc_matrix_with_vector_2D'
    INTEGER                                            :: m, n, n1, n2, m1, m2, k
    REAL(dp), DIMENSION(:    ), POINTER                ::  xx_1D,  yy_1D
    INTEGER                                            :: wxx_1D, wyy_1D
    
    ! Add routine to path
    CALL init_routine( routine_name)
    
    ! Safety
    CALL MatGetSize( A, m, n, perr)
    
    call partition_list(m, par%i, par%n, m1, m2)
    call partition_list(n, par%i, par%n, n1, n2)
    
    IF (n2-n1+1 /= SIZE( xx,1) .OR. m2-m1+1 /= SIZE( yy,1) .OR. SIZE( xx,2) /= SIZE( yy,2)) THEN
      CALL crash('matrix and vector sub-sizes dont match!')
    END IF
    
    ! Allocate shared memory
    allocate(xx_1D( n1:n2 ))
    allocate(yy_1D( m1:m2 ))
    
    
    ! Compute each column separately
    DO k = 1, SIZE( xx,2)
      
      ! Copy this column of x
      xx_1D = xx( :,k)
      
      ! Compute the matrix-vector product
      CALL multiply_PETSc_matrix_with_vector_1D( A, xx_1D, yy_1D)
      
      ! Copy the result back
      yy( :,k) = yy_1D
      
    END DO
    
    ! Clean up after yourself
    deallocate( xx_1D)
    deallocate( yy_1D)
    
    ! Finalise routine path
    CALL finalise_routine( routine_name)
    
  END SUBROUTINE multiply_PETSc_matrix_with_vector_2D

END MODULE petsc_module
