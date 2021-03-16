MODULE mesh_creation_module
  ! Routines for creating the first mesh from a collection of forcing data on a Cartesian grid.

  USE configuration_module,        ONLY: dp, C
  USE parallel_module,             ONLY: par, sync, allocate_shared_memory_int_0D, allocate_shared_memory_dp_0D, &
                                                    allocate_shared_memory_int_1D, allocate_shared_memory_dp_1D, &
                                                    allocate_shared_memory_int_2D, allocate_shared_memory_dp_2D, &
                                                    allocate_shared_memory_int_3D, allocate_shared_memory_dp_3D, &
                                                    allocate_shared_memory_bool_1D, deallocate_shared_memory, &
                                                    adapt_shared_memory_int_1D,    adapt_shared_memory_dp_1D, &
                                                    adapt_shared_memory_int_2D,    adapt_shared_memory_dp_2D, &
                                                    adapt_shared_memory_int_3D,    adapt_shared_memory_dp_3D, &
                                                    adapt_shared_memory_bool_1D                   
  USE data_types_module,           ONLY: type_model_region, type_mesh, type_mesh_config, type_ice_model, type_init_data_fields
  USE mesh_help_functions_module,  ONLY: FindConnectionWidths, FindTriangleAreas, FindVoronoiCellAreas, GetLatLonCoordinates, &
                                         DetermineMeshResolution, WriteMeshToScreen, MergeVertices, SwitchVertices, RedoTriEdgeIndices, CheckMesh, &
                                         Cart_Bilinear_dp, Cart_Bilinear_int, FindCircumcenter, MaxCartOverTriangle_int, MaxCartOverTriangle_dp, &
                                         MinCartOverTriangle_int, SumCartOverTriangle_dp, CalculateDynamicOmega, oblique_sg_projection, IsInTriangle, &
                                         FindPOIXYCoordinates, FindPOIVerticesAndWeights, FindVoronoiCellGeometricCentres, DetermineProcessXYDomain_regular, &
                                         UpdateTriangleCircumcenter, WriteMeshToTextFile, IsEncroachedUpon, IsBoundarySegment
  USE mesh_memory_module,          ONLY: AllocateMesh, AllocateSubmesh, ExtendMesh, ExtendSubmesh, CropMeshMemory, CropSubmeshMemory, &
                                         DeallocateMesh, DeallocateSubmesh, MoveDataFromSubmeshToMesh, AllocateMesh_extra, ShareSubmeshMemory
  USE mesh_Delaunay_module,        ONLY: SplitTriangle, SplitSegment, FlipTrianglePairs, EnsureDelaunay
  USE mesh_derivatives_module,     ONLY: GetNeighbourFunctions, GetMeshCurvatures, GetMeshCurvaturesVertex
  USE mesh_ArakawaC_module,        ONLY: MakeAcMesh
  USE mesh_rectangular_module,     ONLY: CreateSemiRectangularMesh

  IMPLICIT NONE
  
  INCLUDE 'mpif.h'
  
  CONTAINS
  
  ! === Check whether or not a triangle meets all the fitness criteria.
  ! If you want to change the rules for mesh creation, this is where to do it.
  SUBROUTINE IsGoodTriangle( mesh, ti, init, C_mesh, IsGood)
    ! Check if triangle ti of the mesh is Good
    ! A triangle is not Good if:
    !   - its smallest internal angle is too small
    !   - its 2nd order surface deviation (=max(curvature)*typical_length) is too large
    !   - its area exceeds the limits based on ice velocity, grounding line or calving front
  
    ! Input variables
    TYPE(type_mesh),            INTENT(IN)        :: mesh
    INTEGER,                    INTENT(IN)        :: ti
    TYPE(type_init_data_fields),INTENT(IN)        :: init
    TYPE(type_mesh_config),     INTENT(IN)        :: C_mesh

    LOGICAL,                    INTENT(OUT)       :: IsGood

    INTEGER                                       :: vp,vq,vr
    REAL(dp), DIMENSION(2)                        :: p,q,r
    REAL(dp), DIMENSION(2)                        :: pq,qr,rp, POI
    LOGICAL                                       :: isso
    REAL(dp)                                      :: dmax
    INTEGER                                       :: n
    REAL(dp)                                      :: ap,aq,ar,alpha
    REAL(dp)                                      :: trisumel, mean_curvature, dz
    INTEGER                                       :: trinel
    REAL(dp), PARAMETER                           :: Hb_lo = 500._dp
    REAL(dp), PARAMETER                           :: Hb_hi = 1500._dp  
    REAL(dp)                                      :: Hb_max, w_Hb, lr_lo, lr_hi, r_crit  
    INTEGER                                       :: min_mask_int, max_mask_int
    REAL(dp)                                      :: mean_mask_dp
    LOGICAL                                       :: contains_ice, contains_nonice, contains_margin, contains_gl, contains_cf, contains_coast

    IsGood = .TRUE.

    ! Triangle geometry (the basis of the original version of Rupperts Algorithm)
    ! ===========================================================================
    
    vp = mesh%Tri(ti,1)
    vq = mesh%Tri(ti,2)
    vr = mesh%Tri(ti,3)
    
    p  = mesh%V(vp,:)
    q  = mesh%V(vq,:)
    r  = mesh%V(vr,:) 

    ! Triangle legs
    pq = p-q
    qr = q-r
    rp = r-p

    ! Longest leg
    dmax = MAXVAL([NORM2(pq), NORM2(qr), NORM2(rp)])

    ! Internal angles
    ap = ACOS(-(rp(1)*pq(1) + rp(2)*pq(2))/(NORM2(rp)*NORM2(pq)))
    aq = ACOS(-(pq(1)*qr(1) + pq(2)*qr(2))/(NORM2(pq)*NORM2(qr)))
    ar = ACOS(-(rp(1)*qr(1) + rp(2)*qr(2))/(NORM2(rp)*NORM2(qr)))

    ! Smallest internal angle
    alpha = MINVAL([ap, aq, ar])

    IF (alpha < C%mesh_alpha_min) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! If its an edge triangle, check if the third vertex encroaches on the edge segment
    IF (IsBoundarySegment( mesh, vp, vq)) THEN
      CALL IsEncroachedUpon( mesh, vp, vq, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    ELSEIF (IsBoundarySegment( mesh, vq, vr)) THEN
      CALL IsEncroachedUpon( mesh, vq, vr, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    ELSEIF (IsBoundarySegment( mesh, vr, vp)) THEN
      CALL IsEncroachedUpon( mesh, vr, vp, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    END IF
    
    ! Coarsest allowed resolution
    ! ===========================
    
    IF (dmax > C_mesh%res_max * 1.5_dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! Finest allowed resolution
    ! =========================
    
    IF (dmax < C_mesh%res_min * 1.5_dp * 1000._dp) THEN
      IsGood = .TRUE.
      RETURN
    END IF
    
    ! Resolution at points of interest
    ! ================================
    
    DO n = 1, mesh%nPOI
      POI = mesh%POI_XY_coordinates(n,:)
      IF (IsInTriangle( p, q, r, POI) .AND. dmax > mesh%POI_resolutions(n) * 1.5_dp * 1000._dp) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    END DO

    ! Determine what's inside the triangle
    ! ====================================
    
    contains_ice    = .FALSE.
    contains_nonice = .FALSE.
    contains_margin = .FALSE.
    contains_gl     = .FALSE.
    contains_cf     = .FALSE.
    contains_coast  = .FALSE.
    
    CALL MinCartOverTriangle_int( p, q, r, init%mask_ice_cart, init%x, init%y, init%nx, init%ny, min_mask_int, trinel)
    CALL MaxCartOverTriangle_int( p, q, r, init%mask_ice_cart, init%x, init%y, init%nx, init%ny, max_mask_int, trinel)    
    IF (trinel>0) THEN
      IF (max_mask_int==1) contains_ice    = .TRUE.
      IF (min_mask_int==0) contains_nonice = .TRUE.
    ELSE
      CALL Cart_Bilinear_int( init%mask_ice_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, mean_mask_dp)
      IF (mean_mask_dp>0.1_dp) contains_ice    = .TRUE.
      IF (mean_mask_dp<0.9_dp) contains_nonice = .TRUE.
    END IF
    IF (contains_ice .AND. contains_nonice) contains_margin = .TRUE.
    
    CALL MaxCartOverTriangle_int(p,q,r, init%mask_gl_cart, init%x, init%y, init%nx, init%ny, max_mask_int, trinel)    
    IF (trinel>0) THEN
      IF (max_mask_int==1) contains_gl = .TRUE.
    ELSE
      CALL Cart_Bilinear_int( init%mask_gl_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, mean_mask_dp)
      IF (mean_mask_dp>0.1_dp) contains_gl = .TRUE.
    END IF
    
    CALL MaxCartOverTriangle_int(p,q,r, init%mask_cf_cart, init%x, init%y, init%nx, init%ny, max_mask_int, trinel)    
    IF (trinel>0) THEN
      IF (max_mask_int==1) contains_cf = .TRUE.
    ELSE
      CALL Cart_Bilinear_int( init%mask_cf_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, mean_mask_dp)
      IF (mean_mask_dp>0.1_dp) contains_cf = .TRUE.
    END IF
    
    CALL MaxCartOverTriangle_int(p,q,r, init%mask_coast_cart, init%x, init%y, init%nx, init%ny, max_mask_int, trinel)    
    IF (trinel>0) THEN
      IF (max_mask_int==1) contains_coast = .TRUE.
    ELSE
      CALL Cart_Bilinear_int( init%mask_coast_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, mean_mask_dp)
      IF (mean_mask_dp>0.1_dp) contains_coast = .TRUE.
    END IF

    ! Second-order surface deviation (curvature times size)
    ! =====================================================
    
    CALL SumCartOverTriangle_dp(p,q,r, init%surface_curvature_cart, init%x, init%y, init%nx, init%ny, trisumel, trinel)
    IF (trinel>4) THEN
      mean_curvature = trisumel / trinel
    ELSE
      CALL Cart_Bilinear_dp( init%surface_curvature_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, mean_curvature)
    END IF
    dz = 0.5_dp * mean_curvature * dmax**2

    IF (contains_ice .AND. dz > C_mesh%dz_max_ice) THEN
      IsGood = .FALSE.
     RETURN
    END IF

    ! Special area resolution - ice margin, grounding line, calving front
    ! ===================================================================
    
    ! Coastline
    IF (contains_coast .AND. dmax > C_mesh%res_max_coast * 2._dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! Ice margin
    IF (contains_margin .AND. dmax > C_mesh%res_max_margin * 2._dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! Grounding line
    IF (contains_gl .AND. dmax > C_mesh%res_max_gl * 2._dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN
    END IF

    ! Calving front
    IF (contains_cf .AND. dmax > C_mesh%res_max_cf * 2._dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! Ice-free bed topography (higher res for mountains so inception is captured better)
    ! ==================================================================================
    
    CALL MaxCartOverTriangle_dp(p,q,r, init%Hb_cart, init%x, init%y, init%nx, init%ny, Hb_max,trinel)
    IF (trinel==0) THEN
      CALL Cart_Bilinear_dp( init%Hb_cart, init%x, init%y, init%nx, init%ny, (p+q+r)/3._dp, Hb_max)
    END IF
    
    lr_lo = LOG(C_mesh%res_max)
    lr_hi = LOG(C_mesh%res_max_mountain)
    
    w_Hb = MIN(1._dp, MAX(0._dp, (Hb_max - Hb_lo) / (Hb_hi - Hb_lo)))    
    r_crit = EXP( (w_Hb * lr_hi) + ((1._dp - w_Hb) * lr_lo))
    
    IF (contains_nonice .AND. dmax > r_crit * 2._dp * 1000._dp) THEN
      IsGood = .FALSE.
      RETURN      
    END IF

  END SUBROUTINE IsGoodTriangle
  SUBROUTINE IsGoodTriangle_geo_only( mesh, ti, IsGood)
    ! Check if triangle ti of the mesh is Good
    ! A triangle is not Good if:
    !   - its smallest internal angle is too small
    !   - its 2nd order surface deviation (=max(curvature)*typical_length) is too large
    !   - its area exceeds the limits based on ice velocity, grounding line or calving front

    TYPE(type_mesh),            INTENT(IN)        :: mesh
    INTEGER,                    INTENT(IN)        :: ti

    LOGICAL,                    INTENT(OUT)       :: IsGood

    INTEGER                                       :: vp,vq,vr
    REAL(dp), DIMENSION(2)                        :: p,q,r
    REAL(dp), DIMENSION(2)                        :: pq,qr,rp
    REAL(dp)                                      :: ap,aq,ar,alpha
    LOGICAL                                       :: isso
    
    IsGood = .TRUE.

    ! Triangle geometry (the basis of the original version of Rupperts Algorithm)
    ! ===========================================================================
    
    vp = mesh%Tri(ti,1)
    vq = mesh%Tri(ti,2)
    vr = mesh%Tri(ti,3)
    
    p  = mesh%V(vp,:)
    q  = mesh%V(vq,:)
    r  = mesh%V(vr,:)  

    ! Triangle legs
    pq = p-q
    qr = q-r
    rp = r-p

    ! Internal angles
    ap = ACOS(-(rp(1)*pq(1) + rp(2)*pq(2))/(NORM2(rp)*NORM2(pq)))
    aq = ACOS(-(pq(1)*qr(1) + pq(2)*qr(2))/(NORM2(pq)*NORM2(qr)))
    ar = ACOS(-(rp(1)*qr(1) + rp(2)*qr(2))/(NORM2(rp)*NORM2(qr)))

    ! Smallest internal angle
    alpha = MINVAL([ap, aq, ar])

    IF (alpha < C%mesh_alpha_min) THEN
      IsGood = .FALSE.
      RETURN
    END IF
    
    ! If its an edge triangle, check if the third vertex encroaches on the edge segment
    IF (IsBoundarySegment( mesh, vp, vq)) THEN
      CALL IsEncroachedUpon( mesh, vp, vq, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    ELSEIF (IsBoundarySegment( mesh, vq, vr)) THEN
      CALL IsEncroachedUpon( mesh, vq, vr, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    ELSEIF (IsBoundarySegment( mesh, vr, vp)) THEN
      CALL IsEncroachedUpon( mesh, vr, vp, isso)
      IF (isso) THEN
        IsGood = .FALSE.
        RETURN
      END IF
    END IF
    
  END SUBROUTINE IsGoodTriangle_geo_only
    
  ! == Mesh creation routines ==
  SUBROUTINE CreateMeshFromCartData(region)
    ! Create the first mesh, using the data from the initial file to force the resolution.
  
    ! Input variables
    TYPE(type_model_region),    INTENT(INOUT)     :: region
    
    ! Local variables
    INTEGER                                       :: orientation
    TYPE(type_mesh)                               :: submesh
    REAL(dp)                                      :: xmin, xmax, ymin, ymax
    TYPE(type_mesh_config)                        :: C_mesh_final, C_mesh_inc
    REAL(dp)                                      :: res_min
    INTEGER                                       :: rit
    
    CHARACTER(LEN=256) :: submesh_filename, str1, str2
    
    ! If so specified, create a semi-rectangular mesh
    IF (C%do_rectangular) THEN
      CALL CreateSemiRectangularMesh( region%mesh, region%name, MINVAL(region%init%x), MAXVAL(region%init%x), MINVAL(region%init%y), MAXVAL(region%init%y))
      RETURN
    END IF
    
    ! Orientation of domain partitioning: east-west for GRL, north-south everywhere else
    IF (region%name == 'GRL') THEN
      orientation = 1
    ELSE
      orientation = 0
    END IF
        
    ! Determine the domain of this process' submesh. 
    CALL DetermineProcessXYDomain_regular(region, par%i, orientation, xmin, xmax, ymin, ymax)
    
    ! Allocate memory and initialise a dummy mesh
    CALL AllocateSubmesh(     submesh, region%name, 10)    
    CALL InitialiseDummyMesh( submesh, xmin, xmax, ymin, ymax)
    CALL PerturbDummyMesh(    submesh, 0)
        
    ! Determine the parameters for the final mesh
    C_mesh_final%dz_max_ice       = C%dz_max_ice
    C_mesh_final%res_min          = C%res_min
    C_mesh_final%res_max          = C%res_max
    C_mesh_final%res_max_margin   = C%res_max_margin
    C_mesh_final%res_max_gl       = C%res_max_gl
    C_mesh_final%res_max_cf       = C%res_max_cf
    C_mesh_final%res_max_mountain = C%res_max_mountain
    C_mesh_final%res_max_coast    = C%res_max_coast
    
    ! Exception for the EISMINT schematic tests, which start with a flat bedrock and no ice, leading to a very coarse mesh.
    ! After the first time step, a thin ice sheet forms in the area with positive SMB, so that the margin lies in an area
    ! with very coarse resolution. This triggers a mesh update, which results in a mesh with a very wide high-resolution band.
    ! Prevent this by making the very first mesh slightly finer than strictly needed.
    IF (C%do_eismint_experiment) C_mesh_final%res_max = MAX(C%res_min * 2._dp, 16._dp)
        
    ! Refine the process submesh with incrementally increasing resolution, aligning with neighbouring
    ! submeshes after every step, until we reach the final desired resolution
    
    ! Start with everything at the maximum allowed resolution
    C_mesh_inc%dz_max_ice = C_mesh_final%dz_max_ice
    C_mesh_inc%res_max    = C_mesh_final%res_max    
    res_min               = C_mesh_final%res_max
    
    rit = 0
    DO WHILE (res_min > C_mesh_final%res_min)
    
      rit = rit + 1
!      IF (par%master) WRITE(0,'(A,I3,A,F7.2,A)') '    Resolution increment ', rit, ': res_min = ', res_min, ' km'
   
      ! Determine resolutions
      C_mesh_inc%res_min          = MAX( C_mesh_final%res_min,          res_min)
      C_mesh_inc%res_max_margin   = MAX( C_mesh_final%res_max_margin,   res_min)
      C_mesh_inc%res_max_gl       = MAX( C_mesh_final%res_max_gl,       res_min)
      C_mesh_inc%res_max_cf       = MAX( C_mesh_final%res_max_cf,       res_min)
      C_mesh_inc%res_max_mountain = MAX( C_mesh_final%res_max_mountain, res_min)
      C_mesh_inc%res_max_coast    = MAX( C_mesh_final%res_max_coast,    res_min)
      
      ! Refine the process submesh
      CALL RefineMesh( submesh, region%init, C_mesh_inc)
      
      ! Align with neighbouring submeshes
      CALL AlignAllSubmeshes(      submesh, orientation)
      CALL RefineSubmesh_geo_only( submesh)
      
      ! DENK DROM
      WRITE(str1,'(I2)') par%i;   str1 = ADJUSTL(str1)
      WRITE(str2,'(I2)') rit;     str2 = ADJUSTL(str2)
      submesh_filename = 'submesh_p' // TRIM(str1) // '_ri' // TRIM(str2) // '.txt'
!      CALL WriteMeshToTextFile( submesh, submesh_filename)
      
      ! Increase resolution
      res_min = res_min / 2._dp
    
    END DO
    
    ! One final pass with the desired resolution settings 
    CALL RefineMesh(         submesh, region%init, C_mesh_final)
    
    ! Merge the process submeshes, create the final shared-memory mesh
    CALL MergeSubmeshesMeta( submesh, orientation)
    CALL CreateFinalMeshFromMergedSubmesh( submesh, region%mesh)

    IF (par%master) THEN
      WRITE(0,'(A)')                '   Finished creating final mesh.'
      WRITE(0,'(A,I6)')             '    Vertices  : ', region%mesh%nV
      WRITE(0,'(A,I6)')             '    Triangles : ', region%mesh%nTri
      WRITE(0,'(A,F7.1,A,F7.1,A)')  '    Resolution: ', region%mesh%resolution_min/1000._dp, ' - ', region%mesh%resolution_max/1000._dp, ' km'
    END IF
    
  END SUBROUTINE CreateMeshFromCartData
  
  ! == Extended and basic Ruppert's algorithm
  SUBROUTINE RefineMesh( mesh, init, C_mesh)
    ! Refine a mesh. Single-core, but multiple submeshes can be done in parallel on different cores.
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    TYPE(type_init_data_fields),INTENT(IN)        :: init
    TYPE(type_mesh_config),     INTENT(IN)        :: C_mesh
    
    ! Local variables
    INTEGER                                       :: ti, i, ierr, status(MPI_STATUS_SIZE)
    REAL(dp), DIMENSION(2)                        :: p,q,r
    LOGICAL                                       :: IsGood, FinishedRefining, DoExtendMemory
    
    FinishedRefining = .FALSE.
    DoExtendMemory   = .FALSE.
    
    CALL ExtendSubmesh( mesh, mesh%nV + 1000)
    
    mesh%RefMap    = 0
    mesh%RefStack  = 0
    mesh%RefStackN = 0
    DO ti = 1, mesh%nTri
      mesh%RefMap(ti)               = 1
      mesh%RefStackN                = mesh%RefStackN + 1
      mesh%RefStack(mesh%RefStackN) = ti
    END DO
    
    DO WHILE (.NOT. FinishedRefining)
    
      ! Refine the mesh until it's done, or until it's almost out of memory.
      ! ====================================================================
      
      DoExtendMemory = .FALSE.
          
      DO WHILE (mesh%RefStackN > 0)
    
        ! Check the last triangle list in the RefineStack. If it's
        ! Bad, refine it and add the affected triangles to the RefineStack.
      
        ti = mesh%RefStack( mesh%RefStackN)       
        CALL IsGoodTriangle( mesh, ti, init, C_mesh, IsGood)
              
        IF (IsGood) THEN
          ! Remove this triangle from the stack
          mesh%RefMap(ti) = 0
          mesh%RefStack(mesh%RefStackN) = 0
          mesh%RefStackN = mesh%RefStackN - 1
        ELSE
          ! Spit this triangle, add the affected triangles to the stack
          p = mesh%Tricc(ti,:)
          CALL SplitTriangle( mesh, ti, p)
        END IF
        
        ! If we're reaching the memory limit, stop refining and extend the memory.
        IF (mesh%nV > mesh%nV_max - 10) THEN
          DoExtendMemory = .TRUE.
          EXIT
        END IF
        
      END DO ! DO WHILE (mesh%RefStackN > 0)    
      
      ! Check if all processes finished refining. If so, exit.
      ! ======================================================
      
      FinishedRefining = .FALSE.
      IF (mesh%RefStackN == 0) FinishedRefining = .TRUE.      
      CALL MPI_ALLREDUCE( MPI_IN_PLACE, FinishedRefining, 1, MPI_LOGICAL, MPI_LAND, MPI_COMM_WORLD, ierr)      
      IF (FinishedRefining) EXIT  
      
      ! Check if any process needs to extend their memory.
      ! ==================================================
      
      CALL MPI_ALLREDUCE( MPI_IN_PLACE, DoExtendMemory, 1, MPI_LOGICAL, MPI_LOR, MPI_COMM_WORLD, ierr) 
            
      ! By extending the memory to mesh%nV + 1000, we ensure that processes that 
      ! have already finished refining do not keep adding useless extra memory.
      
      IF (DoExtendMemory) THEN
        CALL ExtendSubmesh( mesh, mesh%nV + 1000)
      END IF
    
    END DO ! DO WHILE (.NOT. FinishedRefining)
  
  END SUBROUTINE RefineMesh
  SUBROUTINE RefineMesh_geo_only( mesh)
    ! Refine a mesh, using only triangle geometry as a condition (so really the original version of Ruppert's algorithm)
    ! Meant to be run on the final, merged mesh - called by all processes, but the work is only done by the Master.
    ! Must be called by all to be able to call ExtendMeshMemory if necessary.
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    
    ! Local variables
    INTEGER                                       :: ti, i, ierr, status(MPI_STATUS_SIZE)
    REAL(dp), DIMENSION(2)                        :: p,q,r
    LOGICAL                                       :: IsGood, FinishedRefining, DoExtendMemory
    
    FinishedRefining = .FALSE.
    
    DO WHILE (.NOT. FinishedRefining)
    
      ! Refine the mesh until it's done, or until it's almost out of memory.
      ! ====================================================================
      
      DoExtendMemory = .FALSE.
          
      IF (par%master) THEN
      DO WHILE (mesh%RefStackN > 0)
    
        ! Check the last triangle list in the RefineStack. If it's
        ! Bad, refine it and add the affected triangles to the RefineStack.
      
        ti = mesh%RefStack( mesh%RefStackN)
!        p  = mesh%V(mesh%Tri(ti,1),:)
!        q  = mesh%V(mesh%Tri(ti,2),:)
!        r  = mesh%V(mesh%Tri(ti,3),:)        
        CALL IsGoodTriangle_geo_only( mesh, ti, IsGood)
              
        IF (IsGood) THEN
          ! Remove this triangle from the stack
          mesh%RefMap(ti) = 0
          mesh%RefStack(mesh%RefStackN) = 0
          mesh%RefStackN = mesh%RefStackN - 1
        ELSE
          ! Spit this triangle, add the affected triangles to the stack
          p = mesh%Tricc(ti,:)
          CALL SplitTriangle( mesh, ti, p)
        END IF
        
        ! If we're reaching the memory limit, stop refining and extend the memory.
        IF (mesh%nV > mesh%nV_max - 10) THEN
          DoExtendMemory = .TRUE.
          EXIT
        END IF
        
      END DO ! DO WHILE (mesh%RefStackN > 0)
      END IF ! IF (par%master)
      
      FinishedRefining = .FALSE.
      IF (mesh%RefStackN == 0) FinishedRefining = .TRUE.
      
      ! Check if all processes finished refining. If so, exit.
      ! ======================================================
            
      ! Communicate via the master process
      IF (par%master) THEN
        FinishedRefining = FinishedRefining
        ! Send AllFinishedRefining to all processes
        DO i = 1, par%n-1
          CALL MPI_SEND( FinishedRefining, 1, MPI_INTEGER, i, 0, MPI_COMM_WORLD, ierr)
        END DO
      ELSE
        ! Receive FinishedRefining from the master
        CALL MPI_RECV( FinishedRefining, 1, MPI_LOGICAL, 0, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      END IF
      
      IF (FinishedRefining) EXIT
      
      ! Check if any process needs to extend their memory.
      ! ==================================================
            
      ! Communicate via the master process
      IF (par%master) THEN
        ! Send AllFinishedRefining to all processes
        DO i = 1, par%n-1
          CALL MPI_SEND( DoExtendMemory, 1, MPI_INTEGER, i, 0, MPI_COMM_WORLD, ierr)
        END DO
      ELSE
        ! Receive AllFinishedRefining from the master
        CALL MPI_RECV( DoExtendMemory, 1, MPI_LOGICAL, 0, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      END IF
            
      ! By extending the memory to mesh%nV + 1000, we ensure that processes that 
      ! have already finished refining do not keep adding useless extra memory.
      
      IF (DoExtendMemory) THEN
        CALL ExtendMesh( mesh, mesh%nV + 1000)
      END IF
    
    END DO !DO WHILE (.NOT. FinishedRefining)
  
  END SUBROUTINE RefineMesh_geo_only
  SUBROUTINE RefineSubmesh_geo_only( mesh)
    ! Refine a mesh. Single-core, but multiple submeshes can be done in parallel on different cores.
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    
    ! Local variables
    INTEGER                                       :: ti, i, ierr, status(MPI_STATUS_SIZE)
    REAL(dp), DIMENSION(2)                        :: p,q,r
    LOGICAL                                       :: IsGood, FinishedRefining, DoExtendMemory
    
    FinishedRefining = .FALSE.
    DoExtendMemory   = .FALSE.
    
    CALL ExtendSubmesh( mesh, mesh%nV + 1000)
    
    mesh%RefMap    = 0
    mesh%RefStack  = 0
    mesh%RefStackN = 0
    DO ti = 1, mesh%nTri
      mesh%RefMap(ti)               = 1
      mesh%RefStackN                = mesh%RefStackN + 1
      mesh%RefStack(mesh%RefStackN) = ti
    END DO
    
    DO WHILE (.NOT. FinishedRefining)
    
      ! Refine the mesh until it's done, or until it's almost out of memory.
      ! ====================================================================
      
      DoExtendMemory = .FALSE.
          
      DO WHILE (mesh%RefStackN > 0)
    
        ! Check the last triangle list in the RefineStack. If it's
        ! Bad, refine it and add the affected triangles to the RefineStack.
      
        ti = mesh%RefStack( mesh%RefStackN)
!        p  = mesh%V(mesh%Tri(ti,1),:)
!        q  = mesh%V(mesh%Tri(ti,2),:)
!        r  = mesh%V(mesh%Tri(ti,3),:)          
        CALL IsGoodTriangle_geo_only( mesh, ti, IsGood)
              
        IF (IsGood) THEN
          ! Remove this triangle from the stack
          mesh%RefMap(ti) = 0
          mesh%RefStack(mesh%RefStackN) = 0
          mesh%RefStackN = mesh%RefStackN - 1
        ELSE
          ! Spit this triangle, add the affected triangles to the stack
          p = mesh%Tricc(ti,:)
          CALL SplitTriangle( mesh, ti, p)
        END IF
        
        ! If we're reaching the memory limit, stop refining and extend the memory.
        IF (mesh%nV > mesh%nV_max - 10) THEN
          DoExtendMemory = .TRUE.
          EXIT
        END IF
        
      END DO ! DO WHILE (mesh%RefStackN > 0)  
      
      ! Check if all processes finished refining. If so, exit.
      ! ======================================================
      
      FinishedRefining = .FALSE.
      IF (mesh%RefStackN == 0) FinishedRefining = .TRUE.      
      CALL MPI_ALLREDUCE( MPI_IN_PLACE, FinishedRefining, 1, MPI_LOGICAL, MPI_LAND, MPI_COMM_WORLD, ierr)      
      IF (FinishedRefining) EXIT  
      
      ! Check if any process needs to extend their memory.
      ! ==================================================
      
      CALL MPI_ALLREDUCE( MPI_IN_PLACE, DoExtendMemory, 1, MPI_LOGICAL, MPI_LOR, MPI_COMM_WORLD, ierr) 
            
      ! By extending the memory to mesh%nV + 1000, we ensure that processes that 
      ! have already finished refining do not keep adding useless extra memory.
      
      IF (DoExtendMemory) THEN
        CALL ExtendSubmesh( mesh, mesh%nV + 1000)
      END IF
    
    END DO ! DO WHILE (.NOT. FinishedRefining)
  
  END SUBROUTINE RefineSubmesh_geo_only
  
  ! == Merge submeshes created by parallel processes
  SUBROUTINE MergeSubmeshesMeta( submesh, orientation)
    ! Iteratively merge the submeshes created by the different processes.
  
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh
    INTEGER,                    INTENT(IN)        :: orientation
    
    INTEGER, DIMENSION(8,2)                       :: mergelist
    INTEGER                                       :: nmerge
    
    IF (par%n == 2) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 3) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 4) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 5) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 6) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 7) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 8) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      nmerge = 4
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 9) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      nmerge = 4
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 10) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      nmerge = 5
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 11) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      nmerge = 5
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 12) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      nmerge = 6
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 13) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      nmerge = 6
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      mergelist(2,:) = [ 8, 12]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 14) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      mergelist(7,:) = [12, 13]
      nmerge = 7
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      nmerge = 3
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      mergelist(2,:) = [ 8, 12]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 15) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      mergelist(7,:) = [12, 13]
      nmerge = 7
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      mergelist(4,:) = [12, 14]
      nmerge = 4
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      mergelist(2,:) = [ 8, 12]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    ELSEIF (par%n == 16) THEN
    
      ! Step 1
      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      mergelist(7,:) = [12, 13]
      mergelist(8,:) = [14, 15]
      nmerge = 8
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 2
      mergelist(1,:) = [ 0,  2]
      mergelist(2,:) = [ 4,  6]
      mergelist(3,:) = [ 8, 10]
      mergelist(4,:) = [12, 14]
      nmerge = 4
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 3
      mergelist(1,:) = [ 0,  4]
      mergelist(2,:) = [ 8, 12]
      nmerge = 2
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    
      ! Step 4
      mergelist(1,:) = [ 0,  8]
      nmerge = 1
      CALL MergeSubmeshes( submesh, mergelist, nmerge, orientation)
      
    END IF
  
  END SUBROUTINE MergeSubmeshesMeta
  SUBROUTINE MergeSubmeshes( submesh, mergelist, nmerge, orientation)
    ! Merge the submeshes created by proc1 and proc2
    
    USE, INTRINSIC :: ISO_C_BINDING, ONLY: C_PTR, C_F_POINTER, C_LOC
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh
    INTEGER, DIMENSION(8,2),    INTENT(IN)        :: mergelist
    INTEGER,                    INTENT(IN)        :: nmerge
    INTEGER,                    INTENT(IN)        :: orientation  ! 0 = eastwest, 1 = northsouth
    
    ! Local variables
    TYPE(type_mesh)                               :: submesh_right
    
    INTEGER                                       :: ierr, status(MPI_STATUS_SIZE)
    
    INTEGER                                       :: p_left, p_right, i
    
    INTEGER,  DIMENSION(:,:), ALLOCATABLE         :: T
    INTEGER                                       :: nT, ti, nVl_east, nVr_west
    LOGICAL                                       :: FoundNorth
    INTEGER                                       :: vi, vil, vir, vil_prev, vir_prev
    
    INTEGER                                       :: nVl, nVr, nVtot, nTril, nTrir, nTritot, RefStackNl, RefStackNr, RefStackNtot
    INTEGER                                       :: ci, iti, n, vi1, vi2, nf, ti1, ti2
        
    ! Determine if we're participating as Left, Right or Passive
    ! (Passive still needs to run through the code, to participate in ExtendSubmesh calls)
    
    p_left  = -1
    p_right = -1
    DO i = 1, nmerge
      IF ( mergelist(i,1) == par%i .OR. mergelist(i,2) == par%i) THEN
        p_left  = mergelist(i,1)
        p_right = mergelist(i,2)
      END IF
    END DO
    
    IF (par%i == p_left .OR. par%i == p_right) THEN
!      WRITE(0,'(A,I2,A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': merging mesh ', p_left, ' with mesh ', p_right
    ELSE
!      WRITE(0,'(A,I2,A)')         ' MergeSubmeshes - process ', par%i, ': passively running MergeSubmeshes'
    END IF
    CALL sync
   
  ! Align the two submeshes (make sure all their shared boundary vertices match)
  ! ============================================================================
     
    CALL MergeSubmeshes_align( submesh, orientation, p_left, p_right, nVl_east, nVr_west)
    
  ! Extend memory to accomodate data from submesh_right
  ! ===================================================

    ! First communicate size of aligned meshes, so p_left can extend their memory to accomodate data from p_right
    ! (must be done before sharing memory access, since ExtendSubmesh realloates the memory, resulting in new addresses)

    IF (par%i == p_left) THEN
      CALL MPI_RECV( nVr, 1, MPI_INTEGER, p_right, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)      
      nVl   = submesh%nV
      nVtot = nVl + nVr
    ELSEIF (par%i == p_right) THEN
      CALL MPI_SEND( submesh%nV,  1, MPI_INTEGER, p_left, 0, MPI_COMM_WORLD, ierr)  
    END IF

    IF (par%i == p_left) THEN
      CALL ExtendSubmesh( submesh, nVtot)
    ELSE
      CALL ExtendSubmesh( submesh, submesh%nV)
    END IF
    
  ! Give p_left access to submesh memory from p_right
  ! =================================================  
    
    IF (par%i == p_left .OR. par%i == p_right) THEN
!      IF (par%i == p_left)  WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': gaining   access to submesh memory from process ', p_right
!      IF (par%i == p_right) WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': providing access to submesh memory to   process ', p_left
      CALL ShareSubmeshMemory( p_left, p_right, submesh, submesh_right)
    END IF
    
  ! Merge the data
  ! ==============

    IF (par%i == p_left) THEN
    
  ! Recalculate T with the extra vertices, again sorthed south-north
  ! (must be done to know which vertices to merge. Can be done much
  ! more easily now that we have access to the data from submesh_right)
  ! ===================================================================
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': recalculating T'
      
      ALLOCATE( T( nVl_east + nVr_west, 2))
      
      IF (orientation == 0) THEN 
        
        T = 0
        T(1, :) = [2, 1]
        nT = 1
        
        vil_prev = 2
        vir_prev = 1
        FoundNorth = .FALSE.
        
        DO WHIlE (.NOT. FoundNorth)
          vil = submesh%C(       vil_prev, 1)
          vir = submesh_right%C( vir_prev, submesh_right%nC( vir_prev))
          nT = nT+1
          T(nT,:) = [vil, vir]
          vil_prev = vil
          vir_prev = vir
          IF (vil == 3) FoundNorth = .TRUE.
        END DO
      
      ELSEIF (orientation == 1) THEN
        
        T = 0
        T(1, :) = [3, 2]
        nT = 1
        
        vil_prev = 3
        vir_prev = 2
        FoundNorth = .FALSE.
        
        DO WHIlE (.NOT. FoundNorth)
          vil = submesh%C(       vil_prev, 1)
          vir = submesh_right%C( vir_prev, submesh_right%nC( vir_prev))
          nT = nT+1
          T(nT,:) = [vil, vir]
          vil_prev = vil
          vir_prev = vir
          IF (vil == 4) FoundNorth = .TRUE.
        END DO
      
      END IF ! IF (orientation == 0) THEN
      
    ! Add the data from submesh_right to this process' submesh
    ! ======================================================== 
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': adding data from p_right to p_left'     
  
      nVl          = submesh%nV
      nVr          = submesh_right%nV
      nVtot        = nVl + nVr
      
      nTril        = submesh%nTri
      nTrir        = submesh_right%nTri
      nTritot      = nTril + nTrir
      
      RefStackNl   = submesh%RefStackN
      RefStackNr   = submesh_right%RefStackN
      RefStackNtot = RefStackNl + RefStackNr
      
      submesh%V(              nVl   +1:nVtot  ,:) = submesh_right%V(              1:nVr,  :)
      submesh%nC(             nVl   +1:nVtot    ) = submesh_right%nC(             1:nVr    )
      submesh%C(              nVl   +1:nVtot  ,:) = submesh_right%C(              1:nVr,  :)
      submesh%niTri(          nVl   +1:nVtot    ) = submesh_right%niTri(          1:nVr    )
      submesh%iTri(           nVl   +1:nVtot  ,:) = submesh_right%iTri(           1:nVr,  :)
      submesh%edge_index(     nVl   +1:nVtot    ) = submesh_right%edge_index(     1:nVr    )

      submesh%Tri(            nTril +1:nTritot,:) = submesh_right%Tri(            1:nTrir,:)
      submesh%Tricc(          nTril +1:nTritot,:) = submesh_right%Tricc(          1:nTrir,:)
      submesh%TriC(           nTril +1:nTritot,:) = submesh_right%TriC(           1:nTrir,:)
      submesh%Tri_edge_index( nTril +1:nTritot  ) = submesh_right%Tri_edge_index( 1:nTrir  )

      submesh%RefMap(         nTril +1:nTritot  ) = submesh_right%RefMap(         1:nTrir  )
      
      submesh%RefStack(RefStackNl+1:RefStackNl+RefStackNr) = submesh_right%RefStack(1:RefStackNr)
      submesh%RefStackN = RefStackNl + RefStackNr

      submesh%nV   = nVtot
      submesh%nTri = nTritot
            
    ! Increase the vertex and triangle count of data from submesh_right to start where submesh_left stops
    ! ===================================================================================================
  
      DO vi = nVl+1, nVtot
        DO ci = 1, submesh%nC(vi)
          submesh%C(vi,ci) = submesh%C(vi,ci) + nVl
        END DO
        DO iti = 1, submesh%niTri(vi)
          submesh%iTri(vi,iti) = submesh%iTri(vi,iti) + nTril
        END DO
      END DO
      DO ti = nTril+1, nTritot
        submesh%Tri(ti,:) = submesh%Tri(ti,:) + nVl
        DO n = 1, 3
          IF (submesh%TriC(ti,n)>0) submesh%TriC(ti,n) = submesh%TriC(ti,n) + nTril
        END DO
      END DO

      ! Do the same for the boundary translation table
      DO ti = 1, nT
        T(ti,2) = T(ti,2) + nVl
      END DO

      ! And for the Refinement Stack
      DO n = RefStackNl+1, RefStackNl+RefStackNr
        submesh%RefStack(n) = submesh%RefStack(n) + nTril
      END DO

    ! Merge the shared vertices
    ! =========================
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': merging shared vertices'  
  
      DO ti = 1, nT
        vil = T(ti,1)
        vir = T(ti,2)
        CALL MergeVertices( submesh, nVl, nVr, nTril, nTrir, T, nT, vil, vir, orientation)
      END DO
      
    ! Update domain boundaries
    ! ========================
      
      IF (orientation == 0) THEN
        submesh%xmin = submesh%xmin
        submesh%xmax = submesh_right%xmax        
      ELSEIF (orientation == 1) THEN
        submesh%ymin = submesh%ymin
        submesh%ymax = submesh_right%ymax   
      END IF

    ! Update Tri_edge_index
    ! =====================
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': redoing triangle edge indices'  
    
      CALL RedoTriEdgeIndices( submesh)

    ! Make sure vertices 1, 2, 3, 4 are again at the corners
    ! ======================================================
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': resetting corner vertices'  
    
      IF (orientation == 0) THEN
      
        vi1 = 2
        vi2 = nVl+1
        CALL SwitchVertices( submesh, vi1, vi2)
        vi1 = 3
        vi2 = nVl+2
        CALL SwitchVertices( submesh, vi1, vi2)
      
      ELSEIF (orientation == 1) THEN
      
        vi1 = 3
        vi2 = nVl+1
        CALL SwitchVertices( submesh, vi1, vi2)
        vi1 = 4
        vi2 = nVl+2
        CALL SwitchVertices( submesh, vi1, vi2)
        
      END IF
      
    ! Check if any seam triangles require flipping
    ! ============================================
  
!      WRITE(0,'(A,I2,A,I2)') ' MergeSubmeshes - process ', par%i, ': updating Delaunay triangulation'  
    
      DO ti = 1, nT
      
        vi = T(ti,1)
        
        nf = 0
  
        DO iti = 1, submesh%niTri(vi)
          ti1 = submesh%iTri(vi,iti)
          DO n = 1, 3
            ti2 = submesh%TriC(ti1,n)
            IF (ti2 > 0) THEN              
              nf = nf + 1          
              submesh%Triflip(nf,:) = [ti1,ti2]
            END IF
          END DO
        END DO
  
        ! Flip triangle pairs
        DO WHILE (nf > 0)
          CALL FlipTrianglePairs( submesh, nf)
        END DO
        
      END DO ! DO ti = 1, nT
      
      DEALLOCATE(T)
      
    END IF ! IF (par%i == p_left) THEN
    
    CALL sync
    
  END SUBROUTINE MergeSubmeshes
  SUBROUTINE AlignAllSubmeshes( submesh, orientation)
    ! Align: make sure two adjacent submeshes share all their boundary vertices
    ! This one is used in between resolution increments. This makes sure the differences
    ! in resolution at the process domain interfaces are not too large at the final resolution,
    ! which could give problems with memory (a 100km triangle connected to a bunch of 1km triangles
    ! would lead to exceeding the nconmax = 32 memory limit)
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh
    INTEGER,                    INTENT(IN)        :: orientation  ! 0 = eastwest, 1 = northsouth
    
    INTEGER, DIMENSION(8,2)                       :: mergelist
    INTEGER                                       :: nmerge
    INTEGER                                       :: p_left, p_right, i, nVl_east, nVr_west
    
    ! Since each submesh can only be aligned with one neighbour at a time, and each one has
    ! two neighbours (with the exception of the first and last one), we need two passes.
    
  ! == Step one
  ! ===========
    
    IF (par%n == 2 .OR. par%n == 3) THEN
    
      mergelist(1,:) = [ 0,  1]
      nmerge = 1
      
    ELSEIF (par%n == 4 .OR. par%n == 5) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      nmerge = 2
      
    ELSEIF (par%n == 6 .OR. par%n == 7) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      nmerge = 3
      
    ELSEIF (par%n == 8 .OR. par%n == 9) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      nmerge = 4
      
    ELSEIF (par%n == 10 .OR. par%n == 11) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      nmerge = 5
      
    ELSEIF (par%n == 12 .OR. par%n == 13) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      nmerge = 6
      
    ELSEIF (par%n == 14 .OR. par%n == 15) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      mergelist(7,:) = [12, 13]
      nmerge = 7
      
    ELSEIF (par%n == 16) THEN

      mergelist(1,:) = [ 0,  1]
      mergelist(2,:) = [ 2,  3]
      mergelist(3,:) = [ 4,  5]
      mergelist(4,:) = [ 6,  7]
      mergelist(5,:) = [ 8,  9]
      mergelist(6,:) = [10, 11]
      mergelist(7,:) = [12, 13]
      mergelist(8,:) = [14, 15]
      nmerge = 8
      
    END IF
        
    ! Determine if we're participating as Left, Right or Passive
    ! (Passive still needs to run through the code, to participate in ExtendSubmesh calls)    
    p_left  = -1
    p_right = -1
    DO i = 1, nmerge
      IF ( mergelist(i,1) == par%i .OR. mergelist(i,2) == par%i) THEN
        p_left  = mergelist(i,1)
        p_right = mergelist(i,2)
      END IF
    END DO
    
    CALL MergeSubmeshes_align( submesh, orientation, p_left, p_right, nVl_east, nVr_west)
    
  ! == Step two
  ! ===========
    
    IF (par%n == 2) THEN
    
      RETURN
      
    ELSEIF (par%n == 3 .OR. par%n == 4) THEN

      mergelist(1,:) = [ 1,  2]
      nmerge = 1
      
    ELSEIF (par%n == 5 .OR. par%n == 6) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      nmerge = 2
      
    ELSEIF (par%n == 7 .OR. par%n == 8) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      mergelist(3,:) = [ 5,  6]
      nmerge = 3
      
    ELSEIF (par%n == 9 .OR. par%n == 10) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      mergelist(3,:) = [ 5,  6]
      mergelist(4,:) = [ 7,  8]
      nmerge = 4
      
    ELSEIF (par%n == 11 .OR. par%n == 12) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      mergelist(3,:) = [ 5,  6]
      mergelist(4,:) = [ 7,  8]
      mergelist(5,:) = [ 9, 10]
      nmerge = 5
      
    ELSEIF (par%n == 13 .OR. par%n == 14) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      mergelist(3,:) = [ 5,  6]
      mergelist(4,:) = [ 7,  8]
      mergelist(5,:) = [ 9, 10]
      mergelist(6,:) = [11, 12]
      nmerge = 6
      
    ELSEIF (par%n == 15 .OR. par%n == 16) THEN

      mergelist(1,:) = [ 1,  2]
      mergelist(2,:) = [ 3,  4]
      mergelist(3,:) = [ 5,  6]
      mergelist(4,:) = [ 7,  8]
      mergelist(5,:) = [ 9, 10]
      mergelist(6,:) = [11, 12]
      mergelist(7,:) = [13, 14]
      nmerge = 7
      
    END IF
        
    ! Determine if we're participating as Left, Right or Passive
    ! (Passive still needs to run through the code, to participate in ExtendSubmesh calls)    
    p_left  = -1
    p_right = -1
    DO i = 1, nmerge
      IF ( mergelist(i,1) == par%i .OR. mergelist(i,2) == par%i) THEN
        p_left  = mergelist(i,1)
        p_right = mergelist(i,2)
      END IF
    END DO
    
    CALL MergeSubmeshes_align( submesh, orientation, p_left, p_right, nVl_east, nVr_west)
    
  END SUBROUTINE AlignAllSubmeshes
  SUBROUTINE MergeSubmeshes_align( submesh, orientation, p_left, p_right, nVl_east, nVr_west)
    ! Align: make sure two adjacent submeshes share all their boundary vertices
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh
    INTEGER,                    INTENT(IN)        :: orientation  ! 0 = eastwest, 1 = northsouth
    INTEGER,                    INTENT(IN)        :: p_left, p_right
    INTEGER,                    INTENT(OUT)       :: nVl_east, nVr_west
    
    INTEGER                                       :: ierr, status(MPI_STATUS_SIZE)
    
    INTEGER                                       :: nVl_tot, nVr_tot, nV_extra
    INTEGER,  DIMENSION(:  ), ALLOCATABLE         :: Vil_east, Vir_west, Vi_dummy
    REAL(dp), DIMENSION(:,:), ALLOCATABLE         :: Vl_east, Vr_west, V_dummy
    INTEGER                                       :: vi_prev, vi
    LOGICAL                                       :: FoundNorth
    
    INTEGER,  DIMENSION(:,:), ALLOCATABLE         :: T
    INTEGER                                       :: nT
    INTEGER                                       :: vil, vir
    LOGICAL,  DIMENSION(:  ), ALLOCATABLE         :: FoundAsMatchl, FoundAsMatchr
    REAL(dp), DIMENSION(2  )                      :: p_new, pc, pu, pl
    INTEGER                                       :: vilc, vilu, vill, virc, viru, virl
    
    INTEGER                                       :: vi2
    
!    IF (par%i == p_left .OR. par%i == p_right) THEN
!      WRITE(0,'(A,I2,A,I2,A,I2)') '  MergeSubmeshes_align - process ', par%i, ': aligning mesh ', p_left, ' with mesh ', p_right
!    ELSE
!      WRITE(0,'(A,I2,A)')         '  MergeSubmeshes_align - process ', par%i, ': passively running MergeSubmeshes_align'
!    END IF
!    CALL sync
        
! Create the list of boundary vertices
! ====================================

    ! Allocate dummy memory in non-participating processes (to prevent compiler warnings only)
    IF (.NOT. (par%i == p_left .OR. par%i == p_right)) THEN
      ALLOCATE( FoundAsMatchl(1))
      ALLOCATE( FoundAsMatchr(1))
      ALLOCATE( T(          1,1))
      ALLOCATE( Vil_east(     1))
      ALLOCATE( Vl_east(    1,1))
      ALLOCATE( Vir_west(     1))
      ALLOCATE( Vr_west(    1,1))
      nT = 0
    END IF
    
    IF (par%i == p_left) THEN
      
      ALLOCATE( Vi_dummy( submesh%nV   ))
      ALLOCATE( V_dummy(  submesh%nV, 2))
      
      IF (orientation == 0) THEN
      
        Vi_dummy(1)  = 2
        V_dummy(1,:) = submesh%V(2,:)
        nVl_east     = 1
        nVl_tot      = submesh%nV
        
        FoundNorth = .FALSE.
        vi_prev    = 2
        
        DO WHILE (.NOT. FoundNorth)
          vi = submesh%C(vi_prev,1)
          nVl_east = nVl_east + 1
          Vi_dummy( nVl_east  ) = vi
          V_dummy(  nVl_east,:) = submesh%V(vi,:)
          vi_prev = vi
          IF ( vi == 3) FoundNorth = .TRUE.
        END DO ! DO WHILE (.NOT. FoundNorth)
      
      ELSEIF (orientation == 1) THEN
      
        Vi_dummy(1)  = 3
        V_dummy(1,:) = submesh%V(3,:)
        nVl_east     = 1
        nVl_tot      = submesh%nV
        
        FoundNorth = .FALSE.
        vi_prev    = 3
        
        DO WHILE (.NOT. FoundNorth)
          vi = submesh%C(vi_prev,1)
          nVl_east = nVl_east + 1
          Vi_dummy( nVl_east  ) = vi
          V_dummy(  nVl_east,:) = submesh%V(vi,:)
          vi_prev = vi
          IF ( vi == 4) FoundNorth = .TRUE.
        END DO ! DO WHILE (.NOT. FoundNorth)
        
      END IF
      
      ALLOCATE( Vil_east( nVl_east   ))
      ALLOCATE( Vl_east(  nVl_east, 2))
      Vil_east = Vi_dummy( 1:nVl_east  )
      Vl_east  = V_dummy(  1:nVl_east,:)
      DEALLOCATE( Vi_dummy)
      DEALLOCATE( V_dummy)
      
    ELSEIF (par%i == p_right) THEN
      
      ALLOCATE( Vi_dummy( submesh%nV   ))
      ALLOCATE( V_dummy(  submesh%nV, 2))
      
      IF (orientation == 0) THEN
      
        Vi_dummy(1)  = 1
        V_dummy(1,:) = submesh%V(1,:)
        nVr_west     = 1
        nVr_tot      = submesh%nV
        
        FoundNorth = .FALSE.
        vi_prev    = 1
        
        DO WHILE (.NOT. FoundNorth)
          vi = submesh%C(vi_prev, submesh%nC(vi_prev))
          nVr_west = nVr_west + 1
          Vi_dummy( nVr_west  ) = vi
          V_dummy(  nVr_west,:) = submesh%V(vi,:)
          vi_prev = vi
          IF ( vi == 4) FoundNorth = .TRUE.
        END DO ! DO WHILE (.NOT. FoundNorth)
      
      ELSEIF (orientation == 1) THEN
      
        Vi_dummy(1)  = 2
        V_dummy(1,:) = submesh%V(2,:)
        nVr_west     = 1
        nVr_tot      = submesh%nV
        
        FoundNorth = .FALSE.
        vi_prev    = 2
        
        DO WHILE (.NOT. FoundNorth)
          vi = submesh%C(vi_prev, submesh%nC(vi_prev))
          nVr_west = nVr_west + 1
          Vi_dummy( nVr_west  ) = vi
          V_dummy(  nVr_west,:) = submesh%V(vi,:)
          vi_prev = vi
          IF ( vi == 1) FoundNorth = .TRUE.
        END DO ! DO WHILE (.NOT. FoundNorth)
      
      END IF
      
      ALLOCATE( Vir_west( nVr_west   ))
      ALLOCATE( Vr_west(  nVr_west, 2))
      Vir_west = Vi_dummy( 1:nVr_west  )
      Vr_west  = V_dummy(  1:nVr_west,:)
      DEALLOCATE( Vi_dummy)
      DEALLOCATE( V_dummy)
      
    END IF ! IF (par%i == p_left) THEN
    
! Exchange lists of boundary vertices
! ===================================
    
    IF (par%i == p_left) THEN
    
      ! Receive list of boundary vertices from p_right
      CALL MPI_RECV( nVr_west,  1,          MPI_INTEGER,          p_right, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr) 
      CALL MPI_RECV( nVr_tot,   1,          MPI_INTEGER,          p_right, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)      
      ALLOCATE( Vir_west( nVr_west   ))
      ALLOCATE( Vr_west(  nVr_west, 2))
      CALL MPI_RECV(  Vir_west, nVr_west,   MPI_INTEGER,          p_right, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      CALL MPI_RECV(  Vr_west,  nVr_west*2, MPI_DOUBLE_PRECISION, p_right, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
    
      ! Send list of boundary vertices to p_left
      CALL MPI_SEND( nVl_east, 1,          MPI_INTEGER,          p_right, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( nVl_tot,  1,          MPI_INTEGER,          p_right, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( Vil_east, nVl_east,   MPI_INTEGER,          p_right, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( Vl_east,  nVl_east*2, MPI_DOUBLE_PRECISION, p_right, 0, MPI_COMM_WORLD, ierr)
      
    ELSEIF (par%i == p_right) THEN
    
      ! Send list of boundary vertices to p_left
      CALL MPI_SEND( nVr_west, 1,          MPI_INTEGER,          p_left, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( nVr_tot,  1,          MPI_INTEGER,          p_left, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( Vir_west, nVr_west,   MPI_INTEGER,          p_left, 0, MPI_COMM_WORLD, ierr)
      CALL MPI_SEND( Vr_west,  nVr_west*2, MPI_DOUBLE_PRECISION, p_left, 0, MPI_COMM_WORLD, ierr)
      
      ! Receive list of boundary vertices from p_left
      CALL MPI_RECV( nVl_east,  1,          MPI_INTEGER,          p_left, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr) 
      CALL MPI_RECV( nVl_tot,   1,          MPI_INTEGER,          p_left, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)      
      ALLOCATE( Vil_east( nVl_east   ))
      ALLOCATE( Vl_east(  nVl_east, 2))
      CALL MPI_RECV(  Vil_east, nVl_east,   MPI_INTEGER,          p_left, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      CALL MPI_RECV(  Vl_east,  nVl_east*2, MPI_DOUBLE_PRECISION, p_left, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      
    END IF ! IF (par%i == p_left) THEN
    
! Create the boundary translation table T
! =======================================
    
    IF (par%i == p_left .OR. par%i == p_right) THEN
      
      ! Create T
      ALLOCATE( T( nVl_east + nVr_west, 2))
      ALLOCATE( FoundAsMatchl( nVl_east))
      ALLOCATE( FoundAsMatchr( nVr_west))
      
      IF (orientation == 0) THEN
      
        T(1,:) = [2, 1]
        T(2,:) = [3, 4]
        nT = 2
        
        FoundAsMatchr = .FALSE.
        FoundAsMatchl = .FALSE.
        
        DO vi = 2, nVl_east - 1
          vil = Vil_east( vi)
          DO vi2 = 2, nVr_west - 1
            IF ( FoundAsMatchr( vi2)) CYCLE
            vir = Vir_west( vi2)
            IF ( ABS( Vl_east( vi,2) - Vr_west( vi2,2)) < submesh%tol_dist) THEN
              FoundAsMatchl(vi)  = .TRUE.
              FoundAsMatchr(vi2) = .TRUE.
              nT = nT+1
              T(nT,:) = [vil, vir]
              EXIT
            END IF
          END DO
        END DO
        DO vi2 = 2, nVr_west - 1
          vir = Vir_west(vi2)
          DO vi = 2, nVl_east - 1
            IF (FoundAsMatchl( vi)) CYCLE
            vil = Vil_east(vi)
            IF ( ABS( Vl_east( vi,2) - Vr_west( vi2,2)) < submesh%tol_dist) THEN
              FoundAsMatchl(vi)  = .TRUE.
              FoundAsMatchr(vi2) = .TRUE.
              nT = nT+1
              T(nT,:) = [vil, vir]
              EXIT
            END IF
          END DO
        END DO
      
      ELSEIF (orientation == 1) THEN
      
        T(1,:) = [3, 2]
        T(2,:) = [4, 1]
        nT = 2
        
        FoundAsMatchr = .FALSE.
        FoundAsMatchl = .FALSE.
                
        DO vi = 2, nVl_east - 1
          vil = Vil_east( vi)
          DO vi2 = 2, nVr_west - 1
            IF ( FoundAsMatchr( vi2)) CYCLE
            vir = Vir_west( vi2)
            IF ( ABS( Vl_east( vi,1) - Vr_west( vi2,1)) < submesh%tol_dist) THEN
              FoundAsMatchl(vi)  = .TRUE.
              FoundAsMatchr(vi2) = .TRUE.
              nT = nT+1
              T(nT,:) = [vil, vir]
              EXIT
            END IF
          END DO
        END DO
        DO vi2 = 2, nVr_west - 1
          vir = Vir_west(vi2)
          DO vi = 2, nVl_east - 1
            IF (FoundAsMatchl( vi)) CYCLE
            vil = Vil_east(vi)
            IF ( ABS( Vl_east( vi,1) - Vr_west( vi2,1)) < submesh%tol_dist) THEN
              FoundAsMatchl(vi)  = .TRUE.
              FoundAsMatchr(vi2) = .TRUE.
              nT = nT+1
              T(nT,:) = [vil, vir]
              EXIT
            END IF
          END DO
        END DO
      
      END IF ! IF (orientation == 0) THEN
      
    END IF ! IF (par%i == p_left .OR. par%i == p_right) THEN
    
! Extend submesh memory to accomodate the extra vertices
! ======================================================
    
    IF (par%i == p_left) THEN    
      nV_extra = nVr_west - nT
    ELSEIF (par%i == p_right) THEN
      nV_extra = nVl_east - nT
    ELSE
      nV_extra = 0
    END IF
    
    CALL ExtendSubmesh( submesh, submesh%nV + nV_extra) 
    
! Add the extra vertices to the submesh
! =====================================
    
    IF (par%i == p_left) THEN
      
      DO vi2 = 2, nVr_west-1
        IF (FoundAsMatchr(vi2)) CYCLE

        vir = Vir_west( vi2)
        vil = submesh%nV+1

        ! Find the vertices spanning the segment that needs to be split
        p_new = Vr_west( vi2,:)
        
        DO vi = 1, nVl_east

          vilc = Vil_east( vi)
          vilu = submesh%C( vilc, 1)
          vill = submesh%C( vilc, submesh%nC( vilc))

          pc   = submesh%V(vilc,:)
          pu   = submesh%V(vilu,:)
          pl   = submesh%V(vill,:)
          
          IF (orientation == 0) THEN

            IF ( pu(2) > p_new(2) .AND. pc(2) < p_new(2)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, vilc, vilu, p_new)
              EXIT
            ELSEIF ( pc(2) > p_new(2) .AND. pl(2) < p_new(2)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, vill, vilc, p_new)
              EXIT
            END IF
          
          ELSEIF (orientation == 1) THEN

            IF ( pu(1) < p_new(1) .AND. pc(1) > p_new(1)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, vilc, vilu, p_new)
              EXIT
            ELSEIF ( pc(1) < p_new(1) .AND. pl(1) > p_new(1)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, vill, vilc, p_new)
              EXIT
            END IF
          
          END IF ! IF (orientation == 0) THEN
                    
        END DO ! DO vi = 1:nVl_east
      END DO ! DO vi2 = 1, nVr_west
      
    ELSEIF (par%i == p_right) THEN
      
      DO vi = 2, nVl_east-1
        IF (FoundAsMatchl( vi)) CYCLE

        vil = Vil_east( vi)
        vir = submesh%nV+1

        ! Find the vertices spanning the segment that needs to be split
        p_new = Vl_east( vi,:)
        
        DO vi2 = 1, nVr_west

          virc = Vir_west( vi2)
          viru = submesh%C( virc, submesh%nC( virc))
          virl = submesh%C( virc, 1)

          pc   = submesh%V(virc,:)
          pu   = submesh%V(viru,:)
          pl   = submesh%V(virl,:)
          
          IF (orientation == 0) THEN

            IF ( pu(2) > p_new(2) .AND. pc(2) < p_new(2)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, virc, viru, p_new)
              EXIT
            ELSEIF ( pc(2) > p_new(2) .AND. pl(2) < p_new(2)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, virl, virc, p_new)
              EXIT
            END IF
          
          ELSEIF (orientation == 1) THEN

            IF ( pu(1) < p_new(1) .AND. pc(1) > p_new(1)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, virc, viru, p_new)
              EXIT
            ELSEIF ( pc(1) < p_new(1) .AND. pl(1) > p_new(1)) THEN
              nT = nT+1
              T(nT,:) = [vil, vir]
              CALL SplitSegment( submesh, virl, virc, p_new)
              EXIT
            END IF
          
          END IF ! IF (orientation == 0) THEN
          
        END DO ! DO vi2 = 1, nVr_west        
      END DO ! DO vi = 1, nVl_east
      
    END IF ! IF (par%i == p_left) THEN
    
    ! Crop submesh memory
    CALL CropSubmeshMemory( submesh) 
    
    ! Clean up after yourself!
    DEALLOCATE( Vil_east     )
    DEALLOCATE( Vir_west     )   
    DEALLOCATE( Vl_east      )
    DEALLOCATE( Vr_west      )
    DEALLOCATE( T            )
    DEALLOCATE( FoundAsMatchl)
    DEALLOCATE( FoundAsMatchr)
    
!    WRITE(0,'(A,I2,A)') '  MergeSubmeshes_align - process ', par%i, ': finished'
    
  END SUBROUTINE MergeSubmeshes_align
  SUBROUTINE CreateFinalMeshFromMergedSubmesh( submesh, mesh)
  
    ! In/output variables
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    
    ! Local variables
    INTEGER                                       :: ierr, status(MPI_STATUS_SIZE)
    INTEGER                                       :: p, nV, nTri
    
    ! Communicate final merged mesh size to all processes
    ! ===================================================
    
    IF (par%master) THEN
      nV = submesh%nV
      DO p = 1, par%n-1
        CALL MPI_SEND( nV,   1, MPI_INTEGER, p, 0, MPI_COMM_WORLD, ierr)
        CALL MPI_SEND( nTri, 1, MPI_INTEGER, p, 0, MPI_COMM_WORLD, ierr)
      END DO
    ELSE
      CALL MPI_RECV( nV,   1, MPI_INTEGER, 0, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
      CALL MPI_RECV( nTri, 1, MPI_INTEGER, 0, MPI_ANY_TAG, MPI_COMM_WORLD, status, ierr)
    END IF
  
    ! Copy data from the final merged submesh, deallocate all the submeshes,
    ! do one final refining pass for the new triangles that may be too sharp.
    ! =======================================================================

    CALL AllocateMesh( mesh, submesh%region_name, nV+1000)
    IF (par%master) CALL MoveDataFromSubmeshToMesh( mesh, submesh)  
    CALL DeallocateSubMesh( submesh)
    CALL RefineMesh_geo_only( mesh)
    CALL CropMeshMemory(      mesh)
    CALL sync

    ! Finish up - mesh metadata and extra info
    ! ========================================
                
    ! Determine vertex and triangle domains
    mesh%v1 = MAX(1,         FLOOR(REAL(mesh%nV   *  par%i      / par%n)) + 1)
    mesh%v2 = MIN(mesh%nV,   FLOOR(REAL(mesh%nV   * (par%i + 1) / par%n)))
    mesh%t1 = MAX(1,         FLOOR(REAL(mesh%nTri *  par%i      / par%n)) + 1)
    mesh%t2 = MIN(mesh%nTri, FLOOR(REAL(mesh%nTri * (par%i + 1) / par%n)))
    CALL sync

    mesh%dz_max_ice     = C%dz_max_ice
    mesh%alpha_min      = C%mesh_alpha_min
    
    ! Calculate extra mesh data
    CALL AllocateMesh_extra(              mesh)
    CALL FindVoronoiCellAreas(            mesh)
    CALL GetLatLonCoordinates(            mesh)
    CALL FindTriangleAreas(               mesh)
    CALL FindConnectionWidths(            mesh)
    CALL MakeAcMesh(                      mesh)
    CALL GetNeighbourFunctions(           mesh)
    CALL DetermineMeshResolution(         mesh)
    CALL CalculateDynamicOmega(           mesh)
    CALL FindPOIXYCoordinates(            mesh)
    CALL FindPOIVerticesAndWeights(       mesh)
    CALL FindVoronoiCellGeometricCentres( mesh)
    
    CALL CheckMesh( mesh)
    
  END SUBROUTINE CreateFinalMeshFromMergedSubmesh
  
  ! == "Smooth" a mesh
  SUBROUTINE SmoothMesh( mesh)
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    
    ! Local variables
    INTEGER,  PARAMETER                           :: maximum_number_of_iterations = 200
    REAL(dp), PARAMETER                           :: F_scale = 0.2_dp
    REAL(dp), PARAMETER                           :: F_tol   = 500._dp
    
    INTEGER                                       :: it, vi, ci, vc, ti
    REAL(dp)                                      :: A1, A2, r1, r2, dr, RMS_Fx, RMS_Fy, RMS_F
    REAL(dp), DIMENSION(2)                        :: r_cur, r_norm, FC
    REAL(dp), DIMENSION(:,:), POINTER             :: F
    INTEGER,  DIMENSION(:  ), POINTER             :: LiesNextToEdge
    REAL(dp), DIMENSION(:  ), POINTER             :: InitialDistanceToEdge
    INTEGER                                       :: wF, wLiesNextToEdge, wInitialDistanceToEdge
    
    ! Allocate shared memory
    CALL allocate_shared_memory_dp_2D(  mesh%nV, 2, F, wF)
    CALL allocate_shared_memory_int_1D( mesh%nV, LiesNextToEdge, wLiesNextToEdge)
    CALL allocate_shared_memory_dp_1D(  mesh%nV, InitialDistanceToEdge, wInitialDistanceToEdge)
    
    it = 1
    DO WHILE (it < maximum_number_of_iterations)
    
      it = it + 1
      
      ! Calculate vertex repulsion force
      F = 0._dp
      DO vi = mesh%v1, mesh%v2
      
        ! Only displace non-edge vertices
        IF (mesh%edge_index(vi)>0) CYCLE

        A1 = mesh%A(vi)
        r1 = SQRT( A1 / C%pi)

        DO ci = 1, mesh%nC(vi)
          vc = mesh%C(vi,ci)

          A2 = mesh%A(vc)
          r2 = SQRT( A2 / C%pi)

          r_cur  = mesh%V(vc,:) - mesh%V(vi,:) ! Vector from vi to vc
          r_norm = r_cur / NORM2(r_cur)        ! Unit vector from vi to vc
          dr     = NORM2(r_cur) - (r1+r2)      ! Discrepancy between "observed" and "desired" distance

          FC = r_norm * dr * F_scale
          F(vi,:) = F(vi,:) + FC
        END DO ! DO ci = 1, mesh.nC(vi)
        
      END DO ! DO vi = mesh%v1, mesh%v2
      CALL sync
      
      ! If the mesh meets the smoothness criterion, stop smoothing
      RMS_Fx = 0._dp
      RMS_Fy = 0._dp
      DO vi = 1, mesh%nV
        RMS_Fx = RMS_Fx + (F(vi,1)**2 / REAL(mesh%nV))
        RMS_Fy = RMS_Fy + (F(vi,2)**2 / REAL(mesh%nV))
      END DO      
      RMS_F = (SQRT(RMS_Fx) + SQRT(RMS_Fy)) / F_scale
          
      IF (RMS_F < F_tol) EXIT
      
      ! Displace the vertices
      DO vi = mesh%v1, mesh%v2
        mesh%V(vi,:) = mesh%V(vi,:) + F(vi,:)
      END DO
      CALL sync
      
    END DO ! DO WHILE (.TRUE.)
    
    ! Update triangle circumcenters - can be done in parallel
    DO ti = mesh%t1, mesh%t2
      CALL UpdateTriangleCircumcenter(mesh,ti)      
    END DO
    CALL sync
    
    ! Update the triangulation by flipping triangle pairs where necessary.
    CALL EnsureDelaunay( mesh)
    
    ! Smoothing the mesh changes the Voronoi cells of the vertices; recalculate their areas
    CALL FindVoronoiCellAreas( mesh)
    
    ! Clean up after yourself
    CALL deallocate_shared_memory( wF)
    CALL deallocate_shared_memory( wLiesNextToEdge)
    CALL deallocate_shared_memory( wInitialDistanceToEdge)
    
  END SUBROUTINE SmoothMesh
  
  ! == Initialise a five-vertex dummy mesh
  SUBROUTINE InitialiseDummyMesh(mesh, xmin, xmax, ymin, ymax)
    ! Initialises a 5-vertex, 4-triangle "dummy"  mesh:
    !
    !   v4 - - - - - - - - v3   V          nC     C             niTri   iTri          edge_index
    !   | \              / |    -1 -1      3      2  5  4        2      1  4            6
    !   |  \            /  |     1 -1      3      3  5  1        2      2  1            4
    !   |   \    t3    /   |     1  1      3      4  5  2        2      3  2            2
    !   |    \        /    |    -1  1      3      1  5  3        2      4  3            8
    !   |     \      /     |     0  0      4      1  2  3  4     4      1  2  3  4      0
    !   |      \    /      |
    !   |       \  /       |    Tri           TriC
    !   |  t4    v5    t2  |    1  2  5      2  4  0
    !   |       /  \       |    2  3  5      3  1  0
    !   |      /    \      |    3  4  5      4  2  0
    !   |     /      \     |    4  1  5      1  3  0
    !   |    /        \    |
    !   |   /    t1    \   |
    !   |  /            \  |
    !   | /              \ |
    !   v1 - - - - - - - - v2

    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    REAL(dp),                   INTENT(IN)        :: xmin    ! X and Y ranges of the newly initialised (dummy) mesh
    REAL(dp),                   INTENT(IN)        :: xmax
    REAL(dp),                   INTENT(IN)        :: ymin
    REAL(dp),                   INTENT(IN)        :: ymax

    ! Local variables
    REAL(dp), PARAMETER                           :: tol = 1E-9_dp

    ! Meta properties
    mesh%xmin       = xmin    ! Boundaries of the square domain.
    mesh%xmax       = xmax
    mesh%ymin       = ymin
    mesh%ymax       = ymax
    
    ! Horizontal distance of tolerance. Used for several small routines - points that lie within
    ! this distance of each other (vertices, triangle circumcenters, etc.) are treated as identical.
    mesh%tol_dist   = ((mesh%xmax - mesh%xmin) + (mesh%ymax-mesh%ymin)) * tol / 2._dp
    
    ! Points of interest
    CALL FindPOIXYCoordinates( mesh)

    ! The four corners, plus one central vertex.
    mesh%nV           = 5

    mesh%V            = 0._dp
    mesh%V(1,:)       = [xmin, ymin]
    mesh%V(2,:)       = [xmax, ymin]
    mesh%V(3,:)       = [xmax, ymax]
    mesh%V(4,:)       = [xmin, ymax]
    mesh%V(5,:)       = [(xmin+xmax)/2, (ymin+ymax)/2]

    mesh%edge_index      = 0
    mesh%edge_index(1:5) = [6, 4, 2, 8, 0]

    mesh%nC          = 0
    mesh%nC(1:5)     = [3, 3, 3, 3, 4]

    mesh%C           = 0
    mesh%C(1,1:4)    = [2, 5, 4, 0]
    mesh%C(2,1:4)    = [3, 5, 1, 0]
    mesh%C(3,1:4)    = [4, 5, 2, 0]
    mesh%C(4,1:4)    = [1, 5, 3, 0]
    mesh%C(5,1:4)    = [1, 2, 3, 4]

    mesh%niTri       = 0
    mesh%niTri(1:5)  = [2, 2, 2, 2, 4]

    mesh%iTri        = 0
    mesh%iTri(1,1:4) = [1, 4, 0, 0]
    mesh%iTri(2,1:4) = [2, 1, 0, 0]
    mesh%iTri(3,1:4) = [3, 2, 0, 0]
    mesh%iTri(4,1:4) = [4, 3, 0, 0]
    mesh%iTri(5,1:4) = [1, 2, 3, 4]

    mesh%nTri         = 4

    mesh%Tri          = 0
    mesh%Tri(1,:)     = [1, 2, 5]
    mesh%Tri(2,:)     = [2, 3, 5]
    mesh%Tri(3,:)     = [3, 4, 5]
    mesh%Tri(4,:)     = [4, 1, 5]

    mesh%Tri_edge_index      = 0
    mesh%Tri_edge_index(1:4) = [5, 3, 1, 7]

    mesh%TriC        = 0
    mesh%TriC(1,:)   = [2, 4, 0]
    mesh%TriC(2,:)   = [3, 1, 0]
    mesh%TriC(3,:)   = [4, 2, 0]
    mesh%TriC(4,:)   = [1, 3, 0]

    mesh%Triflip     = 0

    mesh%TriCC = 0._dp
    CALL UpdateTriangleCircumcenter( mesh, 1)
    CALL UpdateTriangleCircumcenter( mesh, 2)
    CALL UpdateTriangleCircumcenter( mesh, 3)
    CALL UpdateTriangleCircumcenter( mesh, 4)
  
    ! Map and stack used for refining
    mesh%RefMap    = 0
    mesh%RefStack  = 0
    mesh%RefStackN = 0

  END SUBROUTINE InitialiseDummyMesh
  SUBROUTINE PerturbDummyMesh( mesh, perturb_dir_global)
    ! "Perturb" the five-vertex dummy mesh; slightly offset the centre vertex,
    ! and split the four edges just next to their midpoints. This ensures that
    ! any new triangles created during mesh refinement are never cocircular.

    ! In/output variables:
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    INTEGER,                    INTENT(IN)        :: perturb_dir_global
    
    ! Local variables:
    INTEGER                                       :: perturb_dir_local, i, vi1, vi2
    REAL(dp), DIMENSION(2)                        :: p
    REAL(dp)                                      :: dx, dy
    
    perturb_dir_local = perturb_dir_global
    DO i = 1, par%i
      perturb_dir_local = 1 - perturb_dir_local
    END DO
    
    IF (perturb_dir_local == 0) THEN
      dx = (mesh%xmax - mesh%xmin) *  C%pi     / 1000._dp ! Offset in x-direction by ~0.3 % of domain width
      dy = (mesh%ymax - mesh%ymin) * (C%pi**2) / 1000._dp ! Offset in y-direction by ~1   % of domain width
    ELSEIF (perturb_dir_local == 1) THEN
      dx = (mesh%xmin - mesh%xmax) *  C%pi     / 1000._dp ! Offset in x-direction by ~0.3 % of domain width
      dy = (mesh%ymin - mesh%ymax) * (C%pi**2) / 1000._dp ! Offset in y-direction by ~1   % of domain width
    ELSE
      WRITE(0,*) ' ERROR: mesh perturbation direction can only be 0 or 1!'
      STOP
    END IF
    
    ! Save perturbation direction
    mesh%perturb_dir = perturb_dir_local
    
    ! Offset the center vertex
    mesh%V( 5,1) = mesh%V( 5,1) + dx / 2._dp
    mesh%V( 5,2) = mesh%V( 5,2) + dy / 2._dp
    
    ! Update triangle circumcenters
    CALL UpdateTriangleCircumcenter( mesh, 1)
    CALL UpdateTriangleCircumcenter( mesh, 2)
    CALL UpdateTriangleCircumcenter( mesh, 3)
    CALL UpdateTriangleCircumcenter( mesh, 4)
    
    ! Split the southern edge
    vi1 = 1
    vi2 = 2
    p = [(mesh%xmax + mesh%xmin) / 2._dp + dx, mesh%ymin]
    CALL SplitSegment( mesh, vi1, vi2, p)
    
    ! Split the eastern edge
    vi1 = 2
    vi2 = 3
    p = [mesh%xmax, (mesh%ymax + mesh%ymin) / 2._dp + dy]
    CALL SplitSegment( mesh, vi1, vi2, p)
    
    ! Split the northern edge
    vi1 = 3
    vi2 = 4
    p = [(mesh%xmax + mesh%xmin) / 2._dp - dx, mesh%ymax]
    CALL SplitSegment( mesh, vi1, vi2, p)
    
    ! Split the western edge
    vi1 = 4
    vi2 = 1
    p = [mesh%xmin, (mesh%ymax + mesh%ymin) / 2._dp - dy]
    CALL SplitSegment( mesh, vi1, vi2, p)
    
  END SUBROUTINE PerturbDummyMesh

END MODULE mesh_creation_module
