MODULE mesh_memory_module
  ! Routines for allocating, deallocating, extending and cropping the memory for the mesh data.

  USE configuration_module,        ONLY: dp, C
  USE parallel_module,             ONLY: par, sync, allocate_shared_memory_int_0D, allocate_shared_memory_dp_0D, &
                                                    allocate_shared_memory_int_1D, allocate_shared_memory_dp_1D, &
                                                    allocate_shared_memory_int_2D, allocate_shared_memory_dp_2D, &
                                                    allocate_shared_memory_int_3D, allocate_shared_memory_dp_3D, &
                                                    allocate_shared_memory_bool_1D, deallocate_shared_memory, &
                                                    adapt_shared_memory_int_1D,    adapt_shared_memory_dp_1D, &
                                                    adapt_shared_memory_int_2D,    adapt_shared_memory_dp_2D, &
                                                    adapt_shared_memory_int_3D,    adapt_shared_memory_dp_3D, &
                                                    adapt_shared_memory_bool_1D, &
                                                    allocate_shared_memory_dist_int_0D, allocate_shared_memory_dist_dp_0D, &
                                                    allocate_shared_memory_dist_int_1D, allocate_shared_memory_dist_dp_1D, &
                                                    allocate_shared_memory_dist_int_2D, allocate_shared_memory_dist_dp_2D, &
                                                    allocate_shared_memory_dist_int_3D, allocate_shared_memory_dist_dp_3D, &
                                                    allocate_shared_memory_dist_bool_1D, &
                                                    adapt_shared_memory_dist_int_1D,    adapt_shared_memory_dist_dp_1D, &
                                                    adapt_shared_memory_dist_int_2D,    adapt_shared_memory_dist_dp_2D, &
                                                    adapt_shared_memory_dist_int_3D,    adapt_shared_memory_dist_dp_3D, &
                                                    adapt_shared_memory_dist_bool_1D, &
                                                    ShareMemoryAccess_int_0D, ShareMemoryAccess_dp_0D, &
                                                    ShareMemoryAccess_int_1D, ShareMemoryAccess_dp_1D, &
                                                    ShareMemoryAccess_int_2D, ShareMemoryAccess_dp_2D, &
                                                    ShareMemoryAccess_int_3D, ShareMemoryAccess_dp_3D
  USE data_types_module,           ONLY: type_mesh

  IMPLICIT NONE
  
  INCLUDE 'mpif.h'

  CONTAINS
  
  SUBROUTINE AllocateMesh(mesh, region_name, nV)
    ! Allocate memory for mesh data

    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    CHARACTER(LEN=3),           INTENT(IN)        :: region_name
    INTEGER,                    INTENT(IN)        :: nV      ! The maximum number of to-allocate vertices
    INTEGER                                       :: nTrimax
    
    mesh%region_name = region_name
    
    CALL allocate_shared_memory_dp_0D(  mesh%xmin,             mesh%wxmin            )
    CALL allocate_shared_memory_dp_0D(  mesh%xmax,             mesh%wxmax            )
    CALL allocate_shared_memory_dp_0D(  mesh%ymin,             mesh%wymin            )
    CALL allocate_shared_memory_dp_0D(  mesh%ymax,             mesh%wymax            )
    CALL allocate_shared_memory_dp_0D(  mesh%tol_dist,         mesh%wtol_dist        )
    CALL allocate_shared_memory_int_0D( mesh%nconmax,          mesh%wnconmax         )
    CALL allocate_shared_memory_int_0D( mesh%nV_max,           mesh%wnV_max          )
    CALL allocate_shared_memory_int_0D( mesh%nTri_max,         mesh%wnTri_max        )
    CALL allocate_shared_memory_int_0D( mesh%nV,               mesh%wnV              )
    CALL allocate_shared_memory_int_0D( mesh%nTri,             mesh%wnTri            )
    CALL allocate_shared_memory_int_0D( mesh%perturb_dir,      mesh%wperturb_dir     )
    CALL allocate_shared_memory_dp_0D(  mesh%alpha_min,        mesh%walpha_min       )
    CALL allocate_shared_memory_dp_0D(  mesh%dz_max_ice,       mesh%wdz_max_ice      )
    CALL allocate_shared_memory_dp_0D(  mesh%resolution_min,   mesh%wresolution_min  )
    CALL allocate_shared_memory_dp_0D(  mesh%resolution_max,   mesh%wresolution_max  )
    
    nTrimax = (2 * nV) - 4
    mesh%nconmax  = C%nconmax
    mesh%nV_max   = nV
    mesh%nTri_max = nTrimax
    
    CALL allocate_shared_memory_dp_2D(  nV,        2,            mesh%V,               mesh%wV              )
    CALL allocate_shared_memory_int_1D( nV,                      mesh%nC,              mesh%wnC             )
    CALL allocate_shared_memory_int_2D( nV,        mesh%nconmax, mesh%C,               mesh%wC              )
    CALL allocate_shared_memory_int_1D( nV,                      mesh%niTri,           mesh%wniTri          )
    CALL allocate_shared_memory_int_2D( nV,        mesh%nconmax, mesh%iTri,            mesh%wiTri           )
    CALL allocate_shared_memory_int_1D( nV,                      mesh%edge_index,      mesh%wedge_index     )
    CALL allocate_shared_memory_int_1D( nV,                      mesh%mesh_old_ti_in,  mesh%wmesh_old_ti_in )
    
    CALL allocate_shared_memory_int_2D( nTrimax, 3,              mesh%Tri,             mesh%wTri            )
    CALL allocate_shared_memory_dp_2D(  nTrimax, 2,              mesh%Tricc,           mesh%wTricc          )
    CALL allocate_shared_memory_int_2D( nTrimax, 3,              mesh%TriC,            mesh%wTriC           )
    CALL allocate_shared_memory_int_1D( nTrimax,                 mesh%Tri_edge_index,  mesh%wTri_edge_index )
    
    CALL allocate_shared_memory_int_2D( nTrimax, 2,              mesh%Triflip,         mesh%wTriflip        )
    CALL allocate_shared_memory_int_1D( nTrimax,                 mesh%RefMap,          mesh%wRefMap         )
    CALL allocate_shared_memory_int_1D( nTrimax,                 mesh%RefStack,        mesh%wRefStack       )
    CALL allocate_shared_memory_int_0D(                          mesh%RefStackN,       mesh%wRefStackN      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VMap,            mesh%wVMap           )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VStack1,         mesh%wVStack1        )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VStack2,         mesh%wVStack2        )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriMap,          mesh%wTriMap         )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriStack1,       mesh%wTriStack1      )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriStack2,       mesh%wTriStack2      )
    
    ! POI stuff
    CALL allocate_shared_memory_int_0D(  mesh%nPOI, mesh%wnPOI)
    
    IF (mesh%region_name == 'NAM') THEN
      mesh%nPOI = C%mesh_nPOI_NAM
    ELSEIF (mesh%region_name == 'EAS') THEN
      mesh%nPOI = C%mesh_nPOI_EAS
    ELSEIF (mesh%region_name == 'GRL') THEN
      mesh%nPOI = C%mesh_nPOI_GRL
    ELSEIF (mesh%region_name == 'ANT') THEN
      mesh%nPOI = C%mesh_nPOI_ANT
    END IF
    
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 2, mesh%POI_coordinates,           mesh%wPOI_coordinates          )
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 2, mesh%POI_XY_coordinates,        mesh%wPOI_XY_coordinates       )
    CALL allocate_shared_memory_dp_1D(  mesh%nPOI,    mesh%POI_resolutions,           mesh%wPOI_resolutions          )
    CALL allocate_shared_memory_int_2D( mesh%nPOI, 3, mesh%POI_vi,                    mesh%wPOI_vi                   )
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 3, mesh%POI_w,                     mesh%wPOI_w                    )

  END SUBROUTINE AllocateMesh
  SUBROUTINE AllocateMesh_extra(mesh)
    ! Allocate memory for mesh data

    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    INTEGER                                       :: nV, nTri

    nV   = mesh%nV
    nTri = mesh%nTri
    
    CALL allocate_shared_memory_dp_1D(  nV,                   mesh%A,               mesh%wA              )
    CALL allocate_shared_memory_dp_2D(  nV,    2,             mesh%VorGC,           mesh%wVorGC          )
    CALL allocate_shared_memory_dp_1D(  nV,                   mesh%R,               mesh%wR              )
    CALL allocate_shared_memory_dp_2D(  nV,     mesh%nconmax, mesh%Cw,              mesh%wCw             )
    CALL allocate_shared_memory_int_1D( nV,                   mesh%mesh_old_ti_in,  mesh%wmesh_old_ti_in )
        
    CALL allocate_shared_memory_dp_1D(  nTri,                 mesh%TriA,            mesh%wTriA           )
    
    CALL allocate_shared_memory_dp_2D(  nTri, 3,              mesh%NxTri,           mesh%wNxTri          )
    CALL allocate_shared_memory_dp_2D(  nTri, 3,              mesh%NyTri,           mesh%wNyTri          )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nx,              mesh%wNx             )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Ny,              mesh%wNy             )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nxx,             mesh%wNxx            )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nxy,             mesh%wNxy            )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nyy,             mesh%wNyy            )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nxm,             mesh%wNxm            )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nym,             mesh%wNym            )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nxxm,            mesh%wNxxm           )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nxym,            mesh%wNxym           )
    CALL allocate_shared_memory_dp_2D(  nV,   mesh%nconmax+1, mesh%Nyym,            mesh%wNyym           )
    
    CALL allocate_shared_memory_dp_1D(  nV,                   mesh%lat,             mesh%wlat            )
    CALL allocate_shared_memory_dp_1D(  nV,                   mesh%lon,             mesh%wlon            )
    
    CALL allocate_shared_memory_dp_1D(  nV,                   mesh%omega,           mesh%womega          )

  END SUBROUTINE AllocateMesh_extra
  SUBROUTINE DeallocateMesh(mesh)
    ! Deallocate memory for mesh data
    
    IMPLICIT NONE
     
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh    
    
    CALL deallocate_shared_memory( mesh%wxmin)
    CALL deallocate_shared_memory( mesh%wxmax)
    CALL deallocate_shared_memory( mesh%wymin)
    CALL deallocate_shared_memory( mesh%wymax)
    CALL deallocate_shared_memory( mesh%wtol_dist)
    CALL deallocate_shared_memory( mesh%wnconmax)
    CALL deallocate_shared_memory( mesh%wnV_max)
    CALL deallocate_shared_memory( mesh%wnTri_max)
    CALL deallocate_shared_memory( mesh%wnV)
    CALL deallocate_shared_memory( mesh%wnTri)
    CALL deallocate_shared_memory( mesh%wperturb_dir)
    CALL deallocate_shared_memory( mesh%walpha_min)
    CALL deallocate_shared_memory( mesh%wdz_max_ice)
    CALL deallocate_shared_memory( mesh%wresolution_min)
    CALL deallocate_shared_memory( mesh%wresolution_max) 
    
    NULLIFY( mesh%xmin)
    NULLIFY( mesh%xmax)
    NULLIFY( mesh%ymin)
    NULLIFY( mesh%ymax)
    NULLIFY( mesh%nconmax)
    NULLIFY( mesh%nV_max)
    NULLIFY( mesh%nTri_max)
    NULLIFY( mesh%nV)
    NULLIFY( mesh%nTri)
    NULLIFY( mesh%alpha_min)
    NULLIFY( mesh%dz_max_ice)
    NULLIFY( mesh%resolution_min)
    NULLIFY( mesh%resolution_max)
    
    CALL deallocate_shared_memory( mesh%wV)
    CALL deallocate_shared_memory( mesh%wA)
    CALL deallocate_shared_memory( mesh%wVorGC)
    CALL deallocate_shared_memory( mesh%wR)
    CALL deallocate_shared_memory( mesh%wnC)
    CALL deallocate_shared_memory( mesh%wC)
    CALL deallocate_shared_memory( mesh%wCw)
    CALL deallocate_shared_memory( mesh%wniTri)
    CALL deallocate_shared_memory( mesh%wiTri)
    CALL deallocate_shared_memory( mesh%wedge_index)
    CALL deallocate_shared_memory( mesh%wmesh_old_ti_in)
    
    NULLIFY( mesh%V)
    NULLIFY( mesh%A)
    NULLIFY( mesh%VorGC)
    NULLIFY( mesh%R)
    NULLIFY( mesh%nC)
    NULLIFY( mesh%C)
    NULLIFY( mesh%Cw)
    NULLIFY( mesh%niTri)
    NULLIFY( mesh%iTri)
    NULLIFY( mesh%edge_index)
    NULLIFY( mesh%mesh_old_ti_in)
    
    CALL deallocate_shared_memory( mesh%wTri)
    CALL deallocate_shared_memory( mesh%wTricc)
    CALL deallocate_shared_memory( mesh%wTriC)
    CALL deallocate_shared_memory( mesh%wTri_edge_index)
    CALL deallocate_shared_memory( mesh%wTriA)
    
    NULLIFY( mesh%Tri)
    NULLIFY( mesh%Tricc)
    NULLIFY( mesh%TriC)
    NULLIFY( mesh%Tri_edge_index)
    NULLIFY( mesh%TriA)
    
    CALL deallocate_shared_memory( mesh%wTriflip)
    CALL deallocate_shared_memory( mesh%wRefMap)
    CALL deallocate_shared_memory( mesh%wRefStack)
    
    NULLIFY( mesh%Triflip)
    NULLIFY( mesh%RefMap)
    NULLIFY( mesh%RefStack)
    
    CALL deallocate_shared_memory( mesh%wVMap)
    CALL deallocate_shared_memory( mesh%wVStack1)
    CALL deallocate_shared_memory( mesh%wVStack2)
    CALL deallocate_shared_memory( mesh%wTriMap)
    CALL deallocate_shared_memory( mesh%wTriStack1)
    CALL deallocate_shared_memory( mesh%wTriStack2)
    
    NULLIFY( mesh%VMap)
    NULLIFY( mesh%VStack1)
    NULLIFY( mesh%VStack2)
    NULLIFY( mesh%TriMap)
    NULLIFY( mesh%TriStack1)
    NULLIFY( mesh%TriStack2)
    
    CALL deallocate_shared_memory( mesh%wNxTri)
    CALL deallocate_shared_memory( mesh%wNyTri)
    CALL deallocate_shared_memory( mesh%wNx)
    CALL deallocate_shared_memory( mesh%wNy)
    CALL deallocate_shared_memory( mesh%wNxx)
    CALL deallocate_shared_memory( mesh%wNxy)
    CALL deallocate_shared_memory( mesh%wNyy)
    CALL deallocate_shared_memory( mesh%wNxm)
    CALL deallocate_shared_memory( mesh%wNym)
    CALL deallocate_shared_memory( mesh%wNxxm)
    CALL deallocate_shared_memory( mesh%wNxym)
    CALL deallocate_shared_memory( mesh%wNyym)

    NULLIFY( mesh%NxTri)
    NULLIFY( mesh%NyTri)
    NULLIFY( mesh%Nx)
    NULLIFY( mesh%Ny)
    NULLIFY( mesh%Nxx)
    NULLIFY( mesh%Nxy)
    NULLIFY( mesh%Nyy)
    NULLIFY( mesh%Nxm)
    NULLIFY( mesh%Nym)
    NULLIFY( mesh%Nxxm)
    NULLIFY( mesh%Nxym)
    NULLIFY( mesh%Nyym)    
    
    CALL deallocate_shared_memory( mesh%wlat)
    CALL deallocate_shared_memory( mesh%wlon)
    
    NULLIFY( mesh%lat)
    NULLIFY( mesh%lon)
    
    CALL deallocate_shared_memory( mesh%womega)
    
    NULLIFY( mesh%omega)
    
    CALL deallocate_shared_memory( mesh%wnAC)
    CALL deallocate_shared_memory( mesh%wVAc)
    CALL deallocate_shared_memory( mesh%wAci)
    CALL deallocate_shared_memory( mesh%wiAci)
    CALL deallocate_shared_memory( mesh%wNx_ac)
    CALL deallocate_shared_memory( mesh%wNy_ac)
    CALL deallocate_shared_memory( mesh%wNp_ac)
    CALL deallocate_shared_memory( mesh%wNo_ac)
    
    NULLIFY( mesh%nAC)
    NULLIFY( mesh%VAc)
    NULLIFY( mesh%Aci)
    NULLIFY( mesh%iAci)
    NULLIFY( mesh%Nx_ac)
    NULLIFY( mesh%Ny_ac)
    NULLIFY( mesh%Np_ac)
    NULLIFY( mesh%No_ac)
    
    CALL deallocate_shared_memory( mesh%wnPOI               )        
    CALL deallocate_shared_memory( mesh%wPOI_coordinates    )
    CALL deallocate_shared_memory( mesh%wPOI_XY_coordinates )
    CALL deallocate_shared_memory( mesh%wPOI_resolutions    )
    CALL deallocate_shared_memory( mesh%wPOI_vi             )
    CALL deallocate_shared_memory( mesh%wPOI_w              )
    
    NULLIFY( mesh%nPOI)
    NULLIFY( mesh%POI_coordinates)
    NULLIFY( mesh%POI_XY_coordinates)
    NULLIFY( mesh%POI_resolutions)
    NULLIFY( mesh%POI_vi)
    NULLIFY( mesh%POI_w)
 
   END SUBROUTINE DeallocateMesh
  SUBROUTINE ExtendMesh(mesh, nV_new)
    ! For when we didn't allocate enough. Field by field, copy the data to a temporary array,
    ! deallocate the old field, allocate a new (bigger) one, and copy the data back.
 
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    INTEGER,                    INTENT(IN)        :: nV_new
  
    INTEGER                                       :: nTrimax_new
 
    nTrimax_new = (2 * nV_new) - 4 
    
    IF (par%master) mesh%nV_max   = nV_new    
    IF (par%master) mesh%nTri_max = nTrimax_new
       
    CALL adapt_shared_memory_dp_2D(  mesh%nV,   nV_new,      2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_dp_2D(  mesh%nV,   nV_new,      2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_dp_2D(  mesh%nV,   nV_new,      2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_int_1D( mesh%nV,   nV_new,                      mesh%nC,             mesh%wnC            )
    CALL adapt_shared_memory_int_2D( mesh%nV,   nV_new,      mesh%nconmax,   mesh%C,              mesh%wC             )   
    CALL adapt_shared_memory_int_1D( mesh%nV,   nV_new,                      mesh%niTri,          mesh%wniTri         )
    CALL adapt_shared_memory_int_2D( mesh%nV,   nV_new,      mesh%nconmax,   mesh%iTri,           mesh%wiTri          )
    CALL adapt_shared_memory_int_1D( mesh%nV,   nV_new,                      mesh%edge_index,     mesh%wedge_index    )
    CALL adapt_shared_memory_int_1D( mesh%nV,   nV_new,                      mesh%mesh_old_ti_in, mesh%wmesh_old_ti_in)
    
    IF (par%master) mesh%mesh_old_ti_in(mesh%nV+1:nV_new) = 1
    
    CALL adapt_shared_memory_int_2D( mesh%nTri, nTrimax_new, 3,              mesh%Tri,            mesh%wTri           )
    CALL adapt_shared_memory_dp_2D(  mesh%nTri, nTrimax_new, 2,              mesh%Tricc,          mesh%wTricc         )    
    CALL adapt_shared_memory_int_2D( mesh%nTri, nTrimax_new, 3,              mesh%TriC,           mesh%wTriC          )  
    CALL adapt_shared_memory_int_1D( mesh%nTri, nTrimax_new,                 mesh%Tri_edge_index, mesh%wTri_edge_index)
    
    CALL adapt_shared_memory_int_2D( mesh%nTri, nTrimax_new, 2,              mesh%Triflip,        mesh%wTriflip       )
    CALL adapt_shared_memory_int_1D( mesh%nTri, nTrimax_new,                 mesh%RefMap,         mesh%wRefMap        )
    CALL adapt_shared_memory_int_1D( mesh%nTri, nTrimax_new,                 mesh%RefStack,       mesh%wRefStack      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VMap,           mesh%wVMap          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VStack1,        mesh%wVStack1       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VStack2,        mesh%wVStack2       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriMap,         mesh%wTriMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriStack1,      mesh%wTriStack1     )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriStack2,      mesh%wTriStack2     )
    
  END SUBROUTINE ExtendMesh
  SUBROUTINE CropMeshMemory(mesh)
    ! For when we allocated too much. Field by field, copy the data to a temporary array,
    ! deallocate the old field, allocate a new (smaller) one, and copy the data back.
 
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
   
    IF (par%master) mesh%nV_max   = mesh%nV
    IF (par%master) mesh%nTri_max = mesh%nTri
       
    CALL adapt_shared_memory_dp_2D(  mesh%nV,   mesh%nV,   2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_int_1D( mesh%nV,   mesh%nV,                   mesh%nC,             mesh%wnC            )
    CALL adapt_shared_memory_int_2D( mesh%nV,   mesh%nV,   mesh%nconmax,   mesh%C,              mesh%wC             )   
    CALL adapt_shared_memory_int_1D( mesh%nV,   mesh%nV,                   mesh%niTri,          mesh%wniTri         )
    CALL adapt_shared_memory_int_2D( mesh%nV,   mesh%nV,   mesh%nconmax,   mesh%iTri,           mesh%wiTri          )
    CALL adapt_shared_memory_int_1D( mesh%nV,   mesh%nV,                   mesh%edge_index,     mesh%wedge_index    )
    CALL adapt_shared_memory_int_1D( mesh%nV,   mesh%nV,                   mesh%mesh_old_ti_in, mesh%wmesh_old_ti_in)
    
    CALL adapt_shared_memory_int_2D( mesh%nTri, mesh%nTri, 3,              mesh%Tri,            mesh%wTri           )
    CALL adapt_shared_memory_dp_2D(  mesh%nTri, mesh%nTri, 2,              mesh%Tricc,          mesh%wTricc         )    
    CALL adapt_shared_memory_int_2D( mesh%nTri, mesh%nTri, 3,              mesh%TriC,           mesh%wTriC          )  
    CALL adapt_shared_memory_int_1D( mesh%nTri, mesh%nTri,                 mesh%Tri_edge_index, mesh%wTri_edge_index)
    
    CALL adapt_shared_memory_int_2D( mesh%nTri, mesh%nTri, 2,              mesh%Triflip,        mesh%wTriflip       )
    CALL adapt_shared_memory_int_1D( mesh%nTri, mesh%nTri,                 mesh%RefMap,         mesh%wRefMap        )
    CALL adapt_shared_memory_int_1D( mesh%nTri, mesh%nTri,                 mesh%RefStack,       mesh%wRefStack      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VMap,           mesh%wVMap          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VStack1,        mesh%wVStack1       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VStack2,        mesh%wVStack2       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriMap,         mesh%wTriMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriStack1,      mesh%wTriStack1     )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriStack2,      mesh%wTriStack2     )
    
  END SUBROUTINE CropMeshMemory
  
  SUBROUTINE AllocateSubmesh( mesh, region_name, nV)
    ! Allocate memory for mesh data

    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    CHARACTER(LEN=3),           INTENT(IN)        :: region_name
    INTEGER,                    INTENT(IN)        :: nV      ! The maximum number of to-allocate vertices
    INTEGER                                       :: nTrimax
    
    mesh%region_name = region_name
    
    CALL allocate_shared_memory_dist_dp_0D(  mesh%xmin,             mesh%wxmin            )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%xmax,             mesh%wxmax            )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%ymin,             mesh%wymin            )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%ymax,             mesh%wymax            )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%tol_dist,         mesh%wtol_dist        )
    CALL allocate_shared_memory_dist_int_0D( mesh%nconmax,          mesh%wnconmax         )
    CALL allocate_shared_memory_dist_int_0D( mesh%nV_max,           mesh%wnV_max          )
    CALL allocate_shared_memory_dist_int_0D( mesh%nTri_max,         mesh%wnTri_max        )
    CALL allocate_shared_memory_dist_int_0D( mesh%nV,               mesh%wnV              )
    CALL allocate_shared_memory_dist_int_0D( mesh%nTri,             mesh%wnTri            )
    CALL allocate_shared_memory_dist_int_0D( mesh%perturb_dir,      mesh%wperturb_dir     )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%alpha_min,        mesh%walpha_min       )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%dz_max_ice,       mesh%wdz_max_ice      )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%resolution_min,   mesh%wresolution_min  )
    CALL allocate_shared_memory_dist_dp_0D(  mesh%resolution_max,   mesh%wresolution_max  )
    
    nTrimax = (2 * nV) - 4
    mesh%nconmax  = C%nconmax
    mesh%nV_max   = nV
    mesh%nTri_max = nTrimax
    
    CALL allocate_shared_memory_dist_dp_2D(  nV,        2,            mesh%V,               mesh%wV              )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%nC,              mesh%wnC             )
    CALL allocate_shared_memory_dist_int_2D( nV,        mesh%nconmax, mesh%C,               mesh%wC              )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%niTri,           mesh%wniTri          )
    CALL allocate_shared_memory_dist_int_2D( nV,        mesh%nconmax, mesh%iTri,            mesh%wiTri           )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%edge_index,      mesh%wedge_index     )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%mesh_old_ti_in,  mesh%wmesh_old_ti_in )
    
    CALL allocate_shared_memory_dist_int_2D( nTrimax, 3,              mesh%Tri,             mesh%wTri            )
    CALL allocate_shared_memory_dist_dp_2D(  nTrimax, 2,              mesh%Tricc,           mesh%wTricc          )
    CALL allocate_shared_memory_dist_int_2D( nTrimax, 3,              mesh%TriC,            mesh%wTriC           )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%Tri_edge_index,  mesh%wTri_edge_index )
    
    CALL allocate_shared_memory_dist_int_2D( nTrimax, 2,              mesh%Triflip,         mesh%wTriflip        )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%RefMap,          mesh%wRefMap         )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%RefStack,        mesh%wRefStack       )
    CALL allocate_shared_memory_dist_int_0D(                          mesh%RefStackN,       mesh%wRefStackN      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VMap,            mesh%wVMap           )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VStack1,         mesh%wVStack1        )
    CALL allocate_shared_memory_dist_int_1D( nV,                      mesh%VStack2,         mesh%wVStack2        )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriMap,          mesh%wTriMap         )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriStack1,       mesh%wTriStack1      )
    CALL allocate_shared_memory_dist_int_1D( nTrimax,                 mesh%TriStack2,       mesh%wTriStack2      )
    
    ! POI stuff
    CALL allocate_shared_memory_int_0D(  mesh%nPOI, mesh%wnPOI)
    
    IF (mesh%region_name == 'NAM') THEN
      mesh%nPOI = C%mesh_nPOI_NAM
    ELSEIF (mesh%region_name == 'EAS') THEN
      mesh%nPOI = C%mesh_nPOI_EAS
    ELSEIF (mesh%region_name == 'GRL') THEN
      mesh%nPOI = C%mesh_nPOI_GRL
    ELSEIF (mesh%region_name == 'ANT') THEN
      mesh%nPOI = C%mesh_nPOI_ANT
    END IF
    
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 2, mesh%POI_coordinates,           mesh%wPOI_coordinates          )
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 2, mesh%POI_XY_coordinates,        mesh%wPOI_XY_coordinates       )
    CALL allocate_shared_memory_dp_1D(  mesh%nPOI,    mesh%POI_resolutions,           mesh%wPOI_resolutions          )
    CALL allocate_shared_memory_int_2D( mesh%nPOI, 3, mesh%POI_vi,                    mesh%wPOI_vi                   )
    CALL allocate_shared_memory_dp_2D(  mesh%nPOI, 3, mesh%POI_w,                     mesh%wPOI_w                    )
    
  END SUBROUTINE AllocateSubmesh
  SUBROUTINE DeallocateSubmesh( mesh)
    ! Deallocate memory for mesh data
    
    IMPLICIT NONE
     
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    
    CALL deallocate_shared_memory( mesh%wxmin)
    CALL deallocate_shared_memory( mesh%wxmax)
    CALL deallocate_shared_memory( mesh%wymin)
    CALL deallocate_shared_memory( mesh%wymax)
    CALL deallocate_shared_memory( mesh%wtol_dist)
    CALL deallocate_shared_memory( mesh%wnconmax)
    CALL deallocate_shared_memory( mesh%wnV_max)
    CALL deallocate_shared_memory( mesh%wnTri_max)
    CALL deallocate_shared_memory( mesh%wnV)
    CALL deallocate_shared_memory( mesh%wnTri)
    CALL deallocate_shared_memory( mesh%walpha_min)
    CALL deallocate_shared_memory( mesh%wdz_max_ice)
    CALL deallocate_shared_memory( mesh%wresolution_min)
    CALL deallocate_shared_memory( mesh%wresolution_max) 
    
    NULLIFY( mesh%xmin)
    NULLIFY( mesh%xmax)
    NULLIFY( mesh%ymin)
    NULLIFY( mesh%ymax)
    NULLIFY( mesh%nconmax)
    NULLIFY( mesh%nV_max)
    NULLIFY( mesh%nTri_max)
    NULLIFY( mesh%nV)
    NULLIFY( mesh%nTri)
    NULLIFY( mesh%alpha_min)
    NULLIFY( mesh%dz_max_ice)
    NULLIFY( mesh%resolution_min)
    NULLIFY( mesh%resolution_max)
    
    CALL deallocate_shared_memory( mesh%wV)
    CALL deallocate_shared_memory( mesh%wnC)
    CALL deallocate_shared_memory( mesh%wC)
    CALL deallocate_shared_memory( mesh%wniTri)
    CALL deallocate_shared_memory( mesh%wiTri)
    CALL deallocate_shared_memory( mesh%wedge_index)
    CALL deallocate_shared_memory( mesh%wmesh_old_ti_in)
    
    NULLIFY( mesh%V)
    NULLIFY( mesh%nC)
    NULLIFY( mesh%C)
    NULLIFY( mesh%niTri)
    NULLIFY( mesh%iTri)
    NULLIFY( mesh%edge_index)
    NULLIFY( mesh%mesh_old_ti_in)
    
    CALL deallocate_shared_memory( mesh%wTri)
    CALL deallocate_shared_memory( mesh%wTricc)
    CALL deallocate_shared_memory( mesh%wTriC)
    CALL deallocate_shared_memory( mesh%wTri_edge_index)
    
    NULLIFY( mesh%Tri)
    NULLIFY( mesh%Tricc)
    NULLIFY( mesh%TriC)
    NULLIFY( mesh%Tri_edge_index)
    
    CALL deallocate_shared_memory( mesh%wTriflip)
    CALL deallocate_shared_memory( mesh%wRefMap)
    CALL deallocate_shared_memory( mesh%wRefStack)
    
    NULLIFY( mesh%Triflip)
    NULLIFY( mesh%RefMap)
    NULLIFY( mesh%RefStack)
    
    CALL deallocate_shared_memory( mesh%wVMap)
    CALL deallocate_shared_memory( mesh%wVStack1)
    CALL deallocate_shared_memory( mesh%wVStack2)
    CALL deallocate_shared_memory( mesh%wTriMap)
    CALL deallocate_shared_memory( mesh%wTriStack1)
    CALL deallocate_shared_memory( mesh%wTriStack2)
    
    NULLIFY( mesh%VMap)
    NULLIFY( mesh%VStack1)
    NULLIFY( mesh%VStack2)
    NULLIFY( mesh%TriMap)
    NULLIFY( mesh%TriStack1)
    NULLIFY( mesh%TriStack2)
    
    CALL deallocate_shared_memory( mesh%wnPOI               )        
    CALL deallocate_shared_memory( mesh%wPOI_coordinates    )
    CALL deallocate_shared_memory( mesh%wPOI_XY_coordinates )
    CALL deallocate_shared_memory( mesh%wPOI_resolutions    )
    CALL deallocate_shared_memory( mesh%wPOI_vi             )
    CALL deallocate_shared_memory( mesh%wPOI_w              )
    
    NULLIFY( mesh%nPOI)
    NULLIFY( mesh%POI_coordinates)
    NULLIFY( mesh%POI_XY_coordinates)
    NULLIFY( mesh%POI_resolutions)
    NULLIFY( mesh%POI_vi)
    NULLIFY( mesh%POI_w)
 
   END SUBROUTINE DeallocateSubmesh
  SUBROUTINE ExtendSubmesh(mesh, nV_new)
    ! For when we didn't allocate enough. Field by field, copy the data to a temporary array,
    ! deallocate the old field, allocate a new (bigger) one, and copy the data back.
 
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    INTEGER,                    INTENT(IN)        :: nV_new
  
    INTEGER                                       :: nTrimax_new
 
    mesh%nV_max = nV_new
    nTrimax_new = (2 * nV_new) - 4 
    
    mesh%nTri_max = nTrimax_new
       
    CALL adapt_shared_memory_dist_dp_2D(  mesh%nV,   nV_new,      2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                      mesh%nC,             mesh%wnC            )
    CALL adapt_shared_memory_dist_int_2D( mesh%nV,   nV_new,      mesh%nconmax,   mesh%C,              mesh%wC             )   
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                      mesh%niTri,          mesh%wniTri         )
    CALL adapt_shared_memory_dist_int_2D( mesh%nV,   nV_new,      mesh%nconmax,   mesh%iTri,           mesh%wiTri          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                      mesh%edge_index,     mesh%wedge_index    )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                      mesh%mesh_old_ti_in, mesh%wmesh_old_ti_in)
    
    mesh%mesh_old_ti_in(mesh%nV+1:nV_new) = 1
    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, nTrimax_new, 3,              mesh%Tri,            mesh%wTri           )
    CALL adapt_shared_memory_dist_dp_2D(  mesh%nTri, nTrimax_new, 2,              mesh%Tricc,          mesh%wTricc         )    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, nTrimax_new, 3,              mesh%TriC,           mesh%wTriC          )  
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,                 mesh%Tri_edge_index, mesh%wTri_edge_index)
    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, nTrimax_new, 2,              mesh%Triflip,        mesh%wTriflip       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,                 mesh%RefMap,         mesh%wRefMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,                 mesh%RefStack,       mesh%wRefStack      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VMap,           mesh%wVMap          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VStack1,        mesh%wVStack1       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   nV_new,                 mesh%VStack2,        mesh%wVStack2       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriMap,         mesh%wTriMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriStack1,      mesh%wTriStack1     )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, nTrimax_new,            mesh%TriStack2,      mesh%wTriStack2     )
    
  END SUBROUTINE ExtendSubmesh
  SUBROUTINE CropSubmeshMemory(mesh)
    ! For when we allocated too much. Field by field, copy the data to a temporary array,
    ! deallocate the old field, allocate a new (smaller) one, and copy the data back.
 
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
   
    mesh%nV_max = mesh%nV
       
    CALL adapt_shared_memory_dist_dp_2D(  mesh%nV,   mesh%nV,   2,              mesh%V,              mesh%wV             )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%nC,             mesh%wnC            )
    CALL adapt_shared_memory_dist_int_2D( mesh%nV,   mesh%nV,   mesh%nconmax,   mesh%C,              mesh%wC             )   
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%niTri,          mesh%wniTri         )
    CALL adapt_shared_memory_dist_int_2D( mesh%nV,   mesh%nV,   mesh%nconmax,   mesh%iTri,           mesh%wiTri          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%edge_index,     mesh%wedge_index    )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%mesh_old_ti_in, mesh%wmesh_old_ti_in)
    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, mesh%nTri, 3,              mesh%Tri,            mesh%wTri           )
    CALL adapt_shared_memory_dist_dp_2D(  mesh%nTri, mesh%nTri, 2,              mesh%Tricc,          mesh%wTricc         )    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, mesh%nTri, 3,              mesh%TriC,           mesh%wTriC          )  
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%Tri_edge_index, mesh%wTri_edge_index)
    
    CALL adapt_shared_memory_dist_int_2D( mesh%nTri, mesh%nTri, 2,              mesh%Triflip,        mesh%wTriflip       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%RefMap,         mesh%wRefMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%RefStack,       mesh%wRefStack      )
    
    ! Distributed shared memory for FloodFill maps and stacks
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VMap,           mesh%wVMap          )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VStack1,        mesh%wVStack1       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nV,   mesh%nV,                   mesh%VStack2,        mesh%wVStack2       )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriMap,         mesh%wTriMap        )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriStack1,      mesh%wTriStack1     )
    CALL adapt_shared_memory_dist_int_1D( mesh%nTri, mesh%nTri,                 mesh%TriStack2,      mesh%wTriStack2     )
    
  END SUBROUTINE CropSubmeshMemory
  SUBROUTINE ShareSubmeshMemory(p_left, p_right, submesh, submesh_right)
    ! Give process p_left access to the submesh memory of p_right
    ! Used in submesh merging
    
    USE, INTRINSIC :: ISO_C_BINDING, ONLY: C_PTR, C_F_POINTER, C_LOC
 
    INTEGER,                    INTENT(IN)        :: p_left
    INTEGER,                    INTENT(IN)        :: p_right
    TYPE(type_mesh),            INTENT(IN)        :: submesh
    TYPE(type_mesh),            INTENT(INOUT)     :: submesh_right
    
    INTEGER                                       :: nV, nTri, nconmax
    
    CALL ShareMemoryAccess_dp_0D(  p_left, p_right, submesh_right%xmin,             submesh%wxmin,             submesh_right%wxmin            )
    CALL ShareMemoryAccess_dp_0D(  p_left, p_right, submesh_right%xmax,             submesh%wxmax,             submesh_right%wxmax            )
    CALL ShareMemoryAccess_dp_0D(  p_left, p_right, submesh_right%ymin,             submesh%wymin,             submesh_right%wymin            )
    CALL ShareMemoryAccess_dp_0D(  p_left, p_right, submesh_right%ymax,             submesh%wymax,             submesh_right%wymax            )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%nconmax,          submesh%wnconmax,          submesh_right%wnconmax         )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%nV_max,           submesh%wnV_max,           submesh_right%wnV_max          )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%nTri_max,         submesh%wnTri_max,         submesh_right%wnTri_max        )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%nV,               submesh%wnV,               submesh_right%wnV              )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%nTri,             submesh%wnTri,             submesh_right%wnTri            )
    
    IF (par%i == p_left) THEN
      nV      = submesh_right%nV_max
      nTri    = submesh_right%nTri_max
      nconmax = submesh_right%nconmax
    ELSEIF (par%i == p_right) THEN
      nV      = submesh%nV_max
      nTri    = submesh%nTri_max
      nconmax = submesh%nconmax
    END IF
    
    CALL ShareMemoryAccess_dp_2D(  p_left, p_right, submesh_right%V,                submesh%wV,                submesh_right%wV,                nV,   2      )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%nC,               submesh%wnC,               submesh_right%wnC,               nV           )
    CALL ShareMemoryAccess_int_2D( p_left, p_right, submesh_right%C,                submesh%wC,                submesh_right%wC,                nV,   nconmax)
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%niTri,            submesh%wniTri,            submesh_right%wniTri,            nV           )
    CALL ShareMemoryAccess_int_2D( p_left, p_right, submesh_right%iTri,             submesh%witri,             submesh_right%wiTri,             nV,   nconmax)
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%edge_index,       submesh%wedge_index,       submesh_right%wedge_index,       nV           )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%mesh_old_ti_in,   submesh%wmesh_old_ti_in,   submesh_right%wmesh_old_ti_in,   nV           )
    
    CALL ShareMemoryAccess_int_2D( p_left, p_right, submesh_right%Tri,              submesh%wTri,              submesh_right%wTri,              nTri, 3      )
    CALL ShareMemoryAccess_dp_2D(  p_left, p_right, submesh_right%Tricc,            submesh%wTricc,            submesh_right%wTricc,            nTri, 2      )
    CALL ShareMemoryAccess_int_2D( p_left, p_right, submesh_right%TriC,             submesh%wTriC,             submesh_right%wTriC,             nTri, 3      )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%Tri_edge_index,   submesh%wTri_edge_index,   submesh_right%wTri_edge_index,   nTri         )
        
    CALL ShareMemoryAccess_int_2D( p_left, p_right, submesh_right%Triflip,          submesh%wTriflip,          submesh_right%wTriflip,          nTri, 2      )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%RefMap,           submesh%wRefMap,           submesh_right%wRefMap,           nTri         )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%RefStack,         submesh%wRefStack,         submesh_right%wRefStack,         nTri         )
    CALL ShareMemoryAccess_int_0D( p_left, p_right, submesh_right%RefStackN,        submesh%wRefStackN,        submesh_right%wRefStackN                      )
    
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%VMap,             submesh%wVMap,             submesh_right%wVMap,             nV           )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%VStack1,          submesh%wVStack1,          submesh_right%wVStack1,          nV           )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%VStack2,          submesh%wVStack2,          submesh_right%wVStack2,          nV           )
    
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%TriMap,           submesh%wTriMap,           submesh_right%wTriMap,           nTri         )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%TriStack1,        submesh%wTriStack1,        submesh_right%wTriStack1,        nTri         )
    CALL ShareMemoryAccess_int_1D( p_left, p_right, submesh_right%TriStack2,        submesh%wTriStack2,        submesh_right%wTriStack2,        nTri         )  
    
  END SUBROUTINE ShareSubmeshMemory
  
  SUBROUTINE MoveDataFromSubmeshToMesh( mesh, submesh)
  
    ! Input variables
    TYPE(type_mesh),            INTENT(INOUT)     :: mesh
    TYPE(type_mesh),            INTENT(IN)        :: submesh
    
    mesh%nV       = submesh%nV
    mesh%nTri     = submesh%nTri
    mesh%nV_max   = submesh%nV_max
    mesh%nTri_max = submesh%nTri_max
    
    mesh%xmin     = submesh%xmin
    mesh%xmax     = submesh%xmax
    mesh%ymin     = submesh%ymin
    mesh%ymax     = submesh%ymax
    mesh%tol_dist = submesh%tol_dist
    
    mesh%perturb_dir = submesh%perturb_dir
        
    mesh%V(              1:submesh%nV  ,:) = submesh%V(              1:submesh%nV  ,:)
    mesh%nC(             1:submesh%nV    ) = submesh%nC(             1:submesh%nV    )
    mesh%C(              1:submesh%nV  ,:) = submesh%C(              1:submesh%nV  ,:)
    mesh%niTri(          1:submesh%nV    ) = submesh%niTri(          1:submesh%nV    )
    mesh%iTri(           1:submesh%nV  ,:) = submesh%iTri(           1:submesh%nV  ,:)
    mesh%edge_index(     1:submesh%nV    ) = submesh%edge_index(     1:submesh%nV    )
    mesh%mesh_old_ti_in( 1:submesh%nV    ) = submesh%mesh_old_ti_in( 1:submesh%nV    )
    
    mesh%Tri(            1:submesh%nTri,:) = submesh%Tri(            1:submesh%nTri,:)
    mesh%Tricc(          1:submesh%nTri,:) = submesh%Tricc(          1:submesh%nTri,:)
    mesh%TriC(           1:submesh%nTri,:) = submesh%TriC(           1:submesh%nTri,:)
    mesh%Tri_edge_index( 1:submesh%nTri  ) = submesh%Tri_edge_index( 1:submesh%nTri  )
    
    mesh%Triflip(        1:submesh%nTri,:) = submesh%Triflip(        1:submesh%nTri,:)
    mesh%RefMap(         1:submesh%nTri  ) = submesh%RefMap(         1:submesh%nTri  )
    mesh%RefStack(       1:submesh%nTri  ) = submesh%RefStack(       1:submesh%nTri  )
    mesh%RefStackN                         = submesh%RefStackN
    
  END SUBROUTINE MoveDataFromSubmeshToMesh

END MODULE mesh_memory_module
