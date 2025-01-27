MODULE data_types_module
  ! Contains all the different types for storing data. Put all together in a separate module so that
  ! all subroutines can use all types without interdependency conflicts, and also to make the 
  ! modules with the actual physics code more readable.
  ! If only Types could be collapsed in BBEdit...

  USE mpi
  USE configuration_module,        ONLY: dp, C
  USE data_types_netcdf_module,    ONLY: type_netcdf_climate_data, type_netcdf_PD_data, type_netcdf_init_data, &
                                         type_netcdf_insolation, type_netcdf_restart, type_netcdf_help_fields, &
                                         type_netcdf_debug, type_netcdf_ICE5G_data, type_netcdf_geothermal_heat_flux

  IMPLICIT NONE
  
  TYPE type_ice_model
    ! The ice dynamics sub-model data structure.
    
    ! Basic data - ice thickness, bedrock & surface elevation, sea level (geoid elevation), englacial temperature, and ice velocities
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi                     ! Ice thickness [m]
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb                     ! Bedrock elevation [m w.r.t. PD sea level]
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb                    ! Change in bedrock elevation w.r.t. PD [m]
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs                     ! Surface elevation [m w.r.t. PD sea level]
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: SL                     ! Sea level (geoid elevation) [m w.r.t. PD sea level]
    REAL(dp), DIMENSION(:    ), POINTER     :: SL_Ac
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ti                     ! Englacial temperature [K]
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ti_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: U_SIA                  ! Vertically averaged ice x-velocity resulting from the SIA [m yr^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: V_SIA
    REAL(dp), DIMENSION(:    ), POINTER     :: Ux_SIA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Uy_SIA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Up_SIA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Uo_SIA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: U_SSA                  ! Vertically averaged ice x-velocity resulting from the SSA [m yr^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: V_SSA
    REAL(dp), DIMENSION(:    ), POINTER     :: Ux_SSA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Uy_SSA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Up_SSA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: Uo_SSA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: U_surf                 ! Total modelled ice x-velocity at the surface [m yr^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: V_surf
    REAL(dp), DIMENSION(:    ), POINTER     :: U_base                 ! Total modelled ice x-velocity at the base    [m yr^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: V_base
    REAL(dp), DIMENSION(:    ), POINTER     :: U_vav                  ! Total modelled vertically averaged ice x-velocity [m yr^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: V_vav
    INTEGER :: wHi,    wHb,    wdHb, wHs,    wSL,    wTi
    INTEGER :: wHi_Ac, wHb_Ac,       wHs_Ac, wSL_Ac, wTi_Ac
    INTEGER :: wU_SIA, wV_SIA, wUx_SIA_Ac, wUy_SIA_Ac, wUp_SIA_Ac, wUo_SIA_Ac
    INTEGER :: wU_SSA, wV_SSA, wUx_SSA_Ac, wUy_SSA_Ac, wUp_SSA_Ac, wUo_SSA_Ac
    INTEGER :: wU_surf, wV_surf, wU_base, wV_base, wU_vav, wV_vav
    
    ! Different masks
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_land
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_land_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_ocean
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_ocean_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_lake
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_lake_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_ice
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_ice_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_sheet
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_sheet_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_shelf
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_shelf_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_coast
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_coast_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_margin
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_margin_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_gl
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_gl_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_cf
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_cf_Ac
    INTEGER,  DIMENSION(:    ), POINTER     :: mask
    INTEGER,  DIMENSION(:    ), POINTER     :: mask_Ac
    INTEGER :: wmask_land,    wmask_ocean,    wmask_lake,    wmask_ice,    wmask_sheet,    wmask_shelf
    INTEGER :: wmask_land_Ac, wmask_ocean_Ac, wmask_lake_Ac, wmask_ice_Ac, wmask_sheet_Ac, wmask_shelf_Ac
    INTEGER :: wmask_coast,    wmask_margin,    wmask_gl,    wmask_cf,    wmask
    INTEGER :: wmask_coast_Ac, wmask_margin_Ac, wmask_gl_Ac, wmask_cf_Ac, wmask_Ac
    
    ! Ice physical properties
    REAL(dp), DIMENSION(:,:  ), POINTER     :: A_flow         ! Flow parameter [Pa^-3 y^-1]
    REAL(dp), DIMENSION(:,:  ), POINTER     :: A_flow_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: A_flow_mean    ! Vertically averaged flow parameter [Pa^-3 y^-1]
    REAL(dp), DIMENSION(:    ), POINTER     :: A_flow_mean_Ac
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ti_pmp         ! The pressure melting point temperature [K]
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Cpi            ! Specific heat capacity of ice [J kg^-1 K^-1].
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ki             ! Conductivity of ice [J m^-1 K^-1 yr^-1].
    INTEGER                             :: wA_flow, wA_flow_Ac, wA_flow_mean, wA_flow_mean_Ac, wTi_pmp, wCpi, wKi
    
    ! Spatial derivatives
    REAL(dp), DIMENSION(:    ), POINTER     :: dHi_dx, dHi_dy, dHi_dt
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb_dx, dHb_dy, dHb_dt
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dx, dHs_dy, dHs_dt
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dx_shelf
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dy_shelf
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dx_shelf_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dy_shelf_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHi_dx_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHi_dy_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHi_dp_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHi_do_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb_dx_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb_dy_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb_dp_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHb_do_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dx_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dy_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dp_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_do_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dSL_dx_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dSL_dy_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dSL_dp_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: dSL_do_Ac
    INTEGER :: wdHi_dx, wdHi_dy, wdHi_dt, wdHb_dx, wdHb_dy, wdHb_dt, wdHs_dx, wdHs_dy, wdHs_dt, wdHs_dx_shelf, wdHs_dy_shelf, wdHs_dx_shelf_Ac, wdHs_dy_shelf_Ac
    INTEGER :: wdHi_dp_Ac, wdHi_do_Ac, wdHi_dx_Ac, wdHi_dy_Ac
    INTEGER :: wdHb_dp_Ac, wdHb_do_Ac, wdHb_dx_Ac, wdHb_dy_Ac
    INTEGER :: wdHs_dp_Ac, wdHs_do_Ac, wdHs_dx_Ac, wdHs_dy_Ac
    INTEGER :: wdSL_dp_Ac, wdSL_do_Ac, wdSL_dx_Ac, wdSL_dy_Ac
    
    ! Zeta derivatives
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dzeta_dt
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dzeta_dx
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dzeta_dy
    REAL(dp), DIMENSION(:    ), POINTER     :: dzeta_dz
    INTEGER :: wdzeta_dt, wdzeta_dx, wdzeta_dy, wdzeta_dz
        
    ! Ice dynamics - SIA
    REAL(dp), DIMENSION(:,:  ), POINTER     :: D_SIA_3D_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: D_SIA_Ac
    REAL(dp), DIMENSION(:    ), POINTER     :: D_SIA
    INTEGER :: wD_SIA_3D_Ac, wD_SIA_Ac, wD_SIA
    
    ! Ice dynamics - SSA
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: SL_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dx_shelf_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dHs_dy_shelf_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: A_flow_mean_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: phi_fric_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: tau_c_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dU_SSA_dx_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dU_SSA_dy_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dV_SSA_dx_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: dV_SSA_dy_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: eta_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: N_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: N_AaAc_prev
    REAL(dp), DIMENSION(:    ), POINTER     :: S_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: eu_i_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: ev_i_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: RHSx_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: RHSy_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: LHSx_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: LHSy_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: resU_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: resV_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: U_SSA_AaAc
    REAL(dp), DIMENSION(:    ), POINTER     :: V_SSA_AaAc
    INTEGER :: wHi_AaAc, wHb_AaAc, wSL_AaAc, wdHs_dx_shelf_AaAc, wdHs_dy_shelf_AaAc, wA_flow_mean_AaAc, wphi_fric_AaAc, wtau_c_AaAc
    INTEGER :: wdU_SSA_dx_AaAc, wdU_SSA_dy_AaAc, wdV_SSA_dx_AaAc, wdV_SSA_dy_AaAc, weta_AaAc, wN_AaAc, wN_AaAc_prev, wS_AaAc
    INTEGER :: weu_i_AaAc, wev_i_AaAc, wRHSx_AaAc, wRHSy_AaAc, wLHSx_AaAc, wLHSy_AaAc, wresU_AaAc, wresV_AaAc
    INTEGER :: wU_SSA_AaAc, wV_SSA_AaAc
    
    ! Ice dynamics- SSA - semi-analytical GL flux
    REAL(dp), DIMENSION(:    ), POINTER     :: Qabs_GL_Ac     ! Semi-analytical grounding line flux
    REAL(dp), DIMENSION(:    ), POINTER     :: Qp_GL_Ac       ! Semi-analytical grounding line flux parallel to the Ac connection
    INTEGER :: wQabs_GL_Ac, wQp_GL_Ac
    
    ! Ice dynamics - ice thickness calculation
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dVi_in
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dVi_out
    INTEGER :: wdVi_in, wdVi_out
    
    ! Thermodynamics
    REAL(dp), DIMENSION(:    ), POINTER     :: frictional_heating   ! Friction heating due to basal sliding
    REAL(dp), DIMENSION(:    ), POINTER     :: GHF                  ! Geothermal heat flux
    REAL(dp), DIMENSION(:,:  ), POINTER     :: U_3D
    REAL(dp), DIMENSION(:,:  ), POINTER     :: V_3D
    REAL(dp), DIMENSION(:,:  ), POINTER     :: W_3D
    INTEGER :: wfrictional_heating, wGHF, wU_3D, wV_3D, wW_3D
    
    ! Isotope content
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi_prev
    REAL(dp), DIMENSION(:    ), POINTER     :: IsoRef
    REAL(dp), DIMENSION(:    ), POINTER     :: IsoSurf
    REAL(dp), DIMENSION(:    ), POINTER     :: MB_iso
    REAL(dp), DIMENSION(:    ), POINTER     :: IsoIce
    REAL(dp), DIMENSION(:    ), POINTER     :: IsoIce_new
    INTEGER :: wHi_prev, wIsoRef, wIsoSurf, wMB_iso, wIsoIce, wIsoIce_new
    
    ! ELRA GIA model
    INTEGER,                    POINTER     :: flex_prof_rad
    REAL(dp), DIMENSION(:,:  ), POINTER     :: flex_prof_grid
    REAL(dp), DIMENSION(:    ), POINTER     :: surface_load_PD_mesh
    REAL(dp), DIMENSION(:    ), POINTER     :: surface_load_mesh
    REAL(dp), DIMENSION(:    ), POINTER     :: surface_load_rel_mesh
    REAL(dp), DIMENSION(:,:  ), POINTER     :: surface_load_rel_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: surface_load_rel_ext_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dHb_eq_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dHb_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dHb_dt_grid
    INTEGER :: wflex_prof_rad, wflex_prof_grid
    INTEGER :: wsurface_load_PD_mesh, wsurface_load_mesh, wsurface_load_rel_mesh, wsurface_load_rel_grid, wsurface_load_rel_ext_grid
    INTEGER :: wdHb_eq_grid, wdHb_grid, wdHb_dt_grid
    
    ! Mesh adaptation data
    REAL(dp), DIMENSION(:    ), POINTER     :: surf_curv
    REAL(dp), DIMENSION(:    ), POINTER     :: log_velocity
    INTEGER :: wsurf_curv, wlog_velocity
          
  END TYPE type_ice_model

  TYPE type_mesh
    ! The unstructured triangular mesh.

    ! Basic meta properties
    CHARACTER(LEN=3)                        :: region_name                   ! NAM, EAS, GRL, ANT
    REAL(dp),                   POINTER     :: lambda_M                      ! Oblique stereographic projection parameters
    REAL(dp),                   POINTER     :: phi_M
    REAL(dp),                   POINTER     :: alpha_stereo
    REAL(dp),                   POINTER     :: xmin                          ! X and Y range of the square covered by the mesh
    REAL(dp),                   POINTER     :: xmax
    REAL(dp),                   POINTER     :: ymin
    REAL(dp),                   POINTER     :: ymax
    REAL(dp),                   POINTER     :: tol_dist                      ! Horizontal distance tolerance; points closer together than this are assumed to be identical (typically set to a billionth of linear domain size)
    INTEGER,                    POINTER     :: nV_mem                        ! Size of allocated memory for vertices
    INTEGER,                    POINTER     :: nTri_mem                      ! Size of allocated memory for triangles
    INTEGER,                    POINTER     :: nC_mem                        ! Maximum allowed number of connections per vertex
    INTEGER,                    POINTER     :: nV                            ! Number of vertices
    INTEGER,                    POINTER     :: nTri                          ! Number of triangles
    INTEGER,                    POINTER     :: perturb_dir                   ! Perturbation direction (0 = anticlockwise, 1 = clockwise)
    REAL(dp),                   POINTER     :: alpha_min                     ! Sharpest inner angle allowed by Rupperts algorithm
    REAL(dp),                   POINTER     :: dz_max_ice                    ! Maximum allowed vertical error in Rupperts algorithm over ice
    REAL(dp),                   POINTER     :: res_max                       ! Maximum resolution anywhere
    REAL(dp),                   POINTER     :: res_max_margin                ! Maximum resolution over the ice margin
    REAL(dp),                   POINTER     :: res_max_gl                    ! Maximum resolution over the grounding line
    REAL(dp),                   POINTER     :: res_max_cf                    ! Maximum resolution over the calving front
    REAL(dp),                   POINTER     :: res_max_mountain              ! Maximum resolution over ice-free mountains  (important for getting the inception right)
    REAL(dp),                   POINTER     :: res_max_coast                 ! Maximum resolution over ice-free coast line (to make plots look nicer)
    REAL(dp),                   POINTER     :: res_min                       ! Minimum resolution anywhere ( = MINVAL([res_max_margin, res_max_gl, res_max_cf]))
    REAL(dp),                   POINTER     :: resolution_min                ! Finest   resolution of the mesh ( = MINVAL(R), where R = distance to nearest neighbour)
    REAL(dp),                   POINTER     :: resolution_max                ! Coarsest resolution of the mesh
    INTEGER :: wlambda_M, wphi_M, walpha_stereo, wxmin, wxmax, wymin, wymax, wtol_dist, wnV_mem, wnTri_mem, wnC_mem, wnV, wnTri, wperturb_dir
    INTEGER :: walpha_min, wdz_max_ice, wres_max, wres_max_margin, wres_max_gl, wres_max_cf, wres_max_mountain, wres_max_coast, wres_min, wresolution_min, wresolution_max

    ! Actual mesh data
    REAL(dp), DIMENSION(:,:  ), POINTER     :: V                             ! The X and Y coordinates of all the vertices
    REAL(dp), DIMENSION(:    ), POINTER     :: A                             ! The area of each vertex's Voronoi cell
    REAL(dp), DIMENSION(:,:  ), POINTER     :: VorGC                         ! The geometric center of each vertex's Voronoi cell
    REAL(dp), DIMENSION(:    ), POINTER     :: R                             ! The resolution (defined as distance to nearest neighbour)
    INTEGER,  DIMENSION(:    ), POINTER     :: nC                            ! The number of other vertices this vertex is connected to
    INTEGER,  DIMENSION(:,:  ), POINTER     :: C                             ! The list   of other vertices this vertex is connected to (ordered counter-clockwise, from edge to edge for edge vertices)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Cw                            ! The width of those connections (=length of the shared Voronoi cell edge), needed for ice fluxes
    INTEGER,  DIMENSION(:    ), POINTER     :: niTri                         ! The number of triangles this vertex is a part of
    INTEGER,  DIMENSION(:,:  ), POINTER     :: iTri                          ! The list   of triangles this vertex is a part of (ordered counter-clockwise)
    INTEGER,  DIMENSION(:    ), POINTER     :: edge_index                    ! Each vertex's Edge Index; 0 = free, 1 = north, 2 = northeast, etc.
    INTEGER,  DIMENSION(:    ), POINTER     :: mesh_old_ti_in                ! When creating a new mesh: for every new mesh vertex, the old mesh triangle that contains it
    INTEGER :: wV, wA, wVorGC, wR, wnC, wC, wCw, wniTri, wiTri, wedge_index, wmesh_old_ti_in ! MPI windows to all these memory spaces

    INTEGER,  DIMENSION(:,:  ), POINTER     :: Tri                           ! The triangle array: Tri(ti) = [vi1, vi2, vi3] (vertices ordered counter-clockwise)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Tricc                         ! The X,Y-coordinates of each triangle's circumcenter
    INTEGER,  DIMENSION(:,:  ), POINTER     :: TriC                          ! The (up to) three neighbour triangles (order across from 1st, 2nd and 3d vertex, respectively)
    INTEGER,  DIMENSION(:    ), POINTER     :: Tri_edge_index                ! Same as for vertices, only NE, SE, etc. aren't used
    REAL(dp), DIMENSION(:    ), POINTER     :: TriA                          ! The area of each triangle
    INTEGER :: wTri, wTricc, wTriC, wTri_edge_index, wTriA ! MPI windows to all these memory spaces
    
    INTEGER,  DIMENSION(:,:  ), POINTER     :: Triflip                       ! List of triangles to flip, used in updating Delaunay triangulation
    INTEGER,  DIMENSION(:    ), POINTER     :: RefMap                        ! Map   of which triangles      have been marked for refining
    INTEGER,  DIMENSION(:    ), POINTER     :: RefStack                      ! Stack of       triangles that have been marked for refining
    INTEGER,                    POINTER     :: RefStackN
    INTEGER :: wTriflip, wRefMap, wRefStack, wRefStackN ! MPI windows to all these memory spaces

    INTEGER,  DIMENSION(:    ), POINTER     :: VMap, VStack1, VStack2        ! Map and stacks for doing a FloodFill-style search on the vertices.  To be used as distributed shared memory.
    INTEGER,  DIMENSION(:    ), POINTER     :: TriMap, TriStack1, TriStack2  ! Map and stacks for doing a FloodFill-style search on the triangles. To be used as distributed shared memory.
    INTEGER :: wVMap, wVStack1, wVStack2, wTriMap, wTriStack1, wTriStack2
    INTEGER :: VStackN1, VStackN2
    INTEGER :: TriStackN1, TriStackN2

    REAL(dp), DIMENSION(:,:  ), POINTER     :: NxTri                         ! The first order neighbour function for each triangle
    REAL(dp), DIMENSION(:,:  ), POINTER     :: NyTri                         ! See subroutine "Calculate_Neighbour_Functions" for explanation    
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nx                            ! The first order neighbour function for each vertex
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ny
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nxx                           ! The second order neighbour functions for each vertex
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nxy
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nyy
    INTEGER :: wNxTri, wNyTri, wNx, wNy, wNxx, wNxy, wNyy, wNxm, wNym, wNxxm, wNxym, wNyym ! MPI windows to all these memory spaces
    
    INTEGER,                    POINTER     :: nAc                           ! The number of Ac vertices
    REAL(dp), DIMENSION(:,:  ), POINTER     :: VAc                           ! x,y coordinates of the Ac vertices
    INTEGER,  DIMENSION(:,:  ), POINTER     :: Aci                           ! Mapping array from the Aa to the Ac mesh
    INTEGER,  DIMENSION(:,:  ), POINTER     :: iAci                          ! Mapping array from the Ac to the Aa mesh
    INTEGER,  DIMENSION(:    ), POINTER     :: edge_index_Ac
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nx_Ac                         ! x          neighbour functions on the Ac mesh
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ny_Ac                         ! y          neighbour functions on the Ac mesh
    REAL(dp), DIMENSION(:    ), POINTER     :: Np_Ac                         ! Parallel   neighbour functions on the Ac mesh
    REAL(dp), DIMENSION(:,:  ), POINTER     :: No_Ac                         ! Orthogonal neighbour functions on the Ac mesh
    INTEGER :: wnAc, wVAc, wAci, wiAci, wedge_index_Ac, wNx_Ac, wNy_Ac, wNp_Ac, wNo_Ac
    
    INTEGER,                    POINTER     :: nVAaAc    
    INTEGER,                    POINTER     :: nTriAaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: VAaAc
    INTEGER,  DIMENSION(:    ), POINTER     :: nCAaAc
    INTEGER,  DIMENSION(:,:  ), POINTER     :: CAaAc
    INTEGER,  DIMENSION(:,:  ), POINTER     :: TriAaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nx_AaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ny_AaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nxx_AaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nxy_AaAc
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Nyy_AaAc
    INTEGER :: wnVAaAc, wnTriAaAc, wVAaAc, wnCAaAc, wCAaAc, wTriAaAc, wNx_AaAc, wNy_AaAc, wNxx_AaAc, wNxy_AaAc, wNyy_AaAc
    
    REAL(dp), DIMENSION(:    ), POINTER     :: lat                           ! Lat, lon coordinates
    REAL(dp), DIMENSION(:    ), POINTER     :: lon
    INTEGER :: wlat, wlon
    
    INTEGER,                    POINTER     :: nPOI                          ! Number of Points of Interest (POI) in this mesh
    REAL(dp), DIMENSION(:,:  ), POINTER     :: POI_coordinates               ! Lat-lon coordinates of a POI
    REAL(dp), DIMENSION(:,:  ), POINTER     :: POI_XY_coordinates            ! X-Y     coordinates of a POI
    REAL(dp), DIMENSION(:    ), POINTER     :: POI_resolutions               ! Resolution          of a POI (km)
    INTEGER,  DIMENSION(:,:  ), POINTER     :: POI_vi                        ! The three vertices surrounding a POI
    REAL(dp), DIMENSION(:,:  ), POINTER     :: POI_w                         ! Their relative weights in trilinear interpolation
    INTEGER :: wnPOI, wPOI_coordinates, wPOI_XY_coordinates, wPOI_resolutions, wPOI_vi, wPOI_w
    
    INTEGER,                    POINTER     :: nV_transect                   ! Number of vertex pairs for the transect
    INTEGER,  DIMENSION(:,:  ), POINTER     :: vi_transect                   ! List   of vertex pairs for the transect
    REAL(dp), DIMENSION(:,:  ), POINTER     :: w_transect                    ! Interpolation weights for the vertex pairs
    INTEGER :: wnV_transect, wvi_transect, ww_transect
    
    ! Parallelisation
    INTEGER                                 :: v1, v2                        ! Vertex domain [v1,v2] of each process (equal number of vertices)
    INTEGER                                 :: t1, t2                        ! Vertex domain [v1,v2] of each process (equal number of triangles)
    INTEGER                                 :: ac1, ac2                      ! Arakawa C   vertex domain [c1,c2] of each process
    INTEGER                                 :: a1, a2                        ! Arakawa A+C vertex domain [a1,a2] of each process
    
    ! Parallelisation - five-colouring
    INTEGER,  DIMENSION(:    ), POINTER     :: colour
    INTEGER,  DIMENSION(:,:  ), POINTER     :: colour_vi
    INTEGER,  DIMENSION(:    ), POINTER     :: colour_nV
    INTEGER                                 :: wcolour, wcolour_vi, wcolour_nV
    INTEGER,  DIMENSION(5)                  :: colour_v1, colour_v2

  END TYPE type_mesh
  
  TYPE type_debug_fields
    ! Dummy variables for debugging
    
    ! NetCDF debug file
    TYPE(type_netcdf_debug)                 :: netcdf
    
    ! Data
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_01
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_02
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_03
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_04
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_05
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_06
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_07
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_08
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_09
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Aa_10
    INTEGER :: wint_2D_Aa_01, wint_2D_Aa_02, wint_2D_Aa_03, wint_2D_Aa_04, wint_2D_Aa_05
    INTEGER :: wint_2D_Aa_06, wint_2D_Aa_07, wint_2D_Aa_08, wint_2D_Aa_09, wint_2D_Aa_10
    
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_01
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_02
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_03
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_04
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_05
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_06
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_07
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_08
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_09
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_Ac_10
    INTEGER :: wint_2D_Ac_01, wint_2D_Ac_02, wint_2D_Ac_03, wint_2D_Ac_04, wint_2D_Ac_05
    INTEGER :: wint_2D_Ac_06, wint_2D_Ac_07, wint_2D_Ac_08, wint_2D_Ac_09, wint_2D_Ac_10
    
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_01
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_02
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_03
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_04
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_05
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_06
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_07
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_08
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_09
    INTEGER,  DIMENSION(:    ), POINTER     :: int_2D_AaAc_10
    INTEGER :: wint_2D_AaAc_01, wint_2D_AaAc_02, wint_2D_AaAc_03, wint_2D_AaAc_04, wint_2D_AaAc_05
    INTEGER :: wint_2D_AaAc_06, wint_2D_AaAc_07, wint_2D_AaAc_08, wint_2D_AaAc_09, wint_2D_AaAc_10
    
    ! Data
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_01
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_02
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_03
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_04
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_05
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_06
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_07
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_08
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_09
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Aa_10
    INTEGER :: wdp_2D_Aa_01, wdp_2D_Aa_02, wdp_2D_Aa_03, wdp_2D_Aa_04, wdp_2D_Aa_05
    INTEGER :: wdp_2D_Aa_06, wdp_2D_Aa_07, wdp_2D_Aa_08, wdp_2D_Aa_09, wdp_2D_Aa_10
    
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_01
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_02
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_03
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_04
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_05
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_06
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_07
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_08
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_09
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_Ac_10
    INTEGER :: wdp_2D_Ac_01, wdp_2D_Ac_02, wdp_2D_Ac_03, wdp_2D_Ac_04, wdp_2D_Ac_05
    INTEGER :: wdp_2D_Ac_06, wdp_2D_Ac_07, wdp_2D_Ac_08, wdp_2D_Ac_09, wdp_2D_Ac_10
    
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_01
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_02
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_03
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_04
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_05
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_06
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_07
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_08
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_09
    REAL(dp), DIMENSION(:    ), POINTER     :: dp_2D_AaAc_10
    INTEGER :: wdp_2D_AaAc_01, wdp_2D_AaAc_02, wdp_2D_AaAc_03, wdp_2D_AaAc_04, wdp_2D_AaAc_05
    INTEGER :: wdp_2D_AaAc_06, wdp_2D_AaAc_07, wdp_2D_AaAc_08, wdp_2D_AaAc_09, wdp_2D_AaAc_10
    
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_01
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_02
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_03
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_04
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_05
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_06
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_07
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_08
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_09
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_3D_Aa_10
    INTEGER :: wdp_3D_Aa_01, wdp_3D_Aa_02, wdp_3D_Aa_03, wdp_3D_Aa_04, wdp_3D_Aa_05
    INTEGER :: wdp_3D_Aa_06, wdp_3D_Aa_07, wdp_3D_Aa_08, wdp_3D_Aa_09, wdp_3D_Aa_10
    
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_01
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_02
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_03
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_04
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_05
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_06
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_07
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_08
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_09
    REAL(dp), DIMENSION(:,:  ), POINTER     :: dp_2D_monthly_Aa_10
    INTEGER :: wdp_2D_monthly_Aa_01, wdp_2D_monthly_Aa_02, wdp_2D_monthly_Aa_03, wdp_2D_monthly_Aa_04, wdp_2D_monthly_Aa_05
    INTEGER :: wdp_2D_monthly_Aa_06, wdp_2D_monthly_Aa_07, wdp_2D_monthly_Aa_08, wdp_2D_monthly_Aa_09, wdp_2D_monthly_Aa_10
    
  END TYPE type_debug_fields
  
  TYPE type_remapping_trilin
    ! Indices and weights for mapping data between two meshes, using trilinear interpolation
    
    INTEGER,  DIMENSION(:,:  ), POINTER :: vi   ! Indices of vertices from mesh_src contributing to this mesh_dst vertex
    REAL(dp), DIMENSION(:,:  ), POINTER :: w    ! Weights of vertices from mesh_src contributing to this mesh_dst vertex
    
    INTEGER :: wvi, ww
    
  END TYPE type_remapping_trilin
  
  TYPE type_remapping_nearest_neighbour
    ! Indices and weights for mapping data between two meshes, using nearest-neighbour interpolation
    
    INTEGER,  DIMENSION(:    ), POINTER :: vi   ! Index of mesh_src vertex nearest to this mesh_dst vertex
    
    INTEGER :: wvi
    
  END TYPE type_remapping_nearest_neighbour
  
  TYPE type_remapping_conservative_intermediate_Ac_local
    ! Intermediate data used in creating conservative remapping arrays
    
    INTEGER                                 :: n_tot
    INTEGER                                 :: n_max
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: nS
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: sli1
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: sli2
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: vi_opp_left
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: vi_opp_right
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_xdy
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_mxydx
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_xydy
  
  END TYPE type_remapping_conservative_intermediate_Ac_local
  
  TYPE type_remapping_conservative_intermediate_Ac_shared
    ! Intermediate data used in creating conservative remapping arrays
    
    INTEGER,                    POINTER :: n_tot
    INTEGER,                    POINTER :: n_max
    INTEGER,  DIMENSION(:    ), POINTER :: nS
    INTEGER,  DIMENSION(:    ), POINTER :: sli1
    INTEGER,  DIMENSION(:    ), POINTER :: sli2
    INTEGER,  DIMENSION(:    ), POINTER :: vi_opp_left
    INTEGER,  DIMENSION(:    ), POINTER :: vi_opp_right
    REAL(dp), DIMENSION(:    ), POINTER :: LI_xdy
    REAL(dp), DIMENSION(:    ), POINTER :: LI_mxydx
    REAL(dp), DIMENSION(:    ), POINTER :: LI_xydy
    INTEGER :: wn_tot, wn_max, wnS, wsli1, wsli2, wvi_opp_left, wvi_opp_right, wLI_xdy, wLI_mxydx, wLI_xydy
  
  END TYPE type_remapping_conservative_intermediate_Ac_shared
  
  TYPE type_remapping_conservative_intermediate_local
    ! Intermediate data used in creating conservative remapping arrays
    
    INTEGER                                 :: n_tot
    INTEGER                                 :: n_max
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: nV
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: vli1
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: vli2
    INTEGER,  DIMENSION(:    ), ALLOCATABLE :: vi_opp
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_xdy
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_mxydx
    REAL(dp), DIMENSION(:    ), ALLOCATABLE :: LI_xydy
  
  END TYPE type_remapping_conservative_intermediate_local
  
  TYPE type_remapping_conservative_intermediate_shared
    ! Intermediate data used in creating conservative remapping arrays
    
    INTEGER,                    POINTER :: n_tot
    INTEGER,                    POINTER :: n_max
    INTEGER,  DIMENSION(:    ), POINTER :: nV
    INTEGER,  DIMENSION(:    ), POINTER :: vli1
    INTEGER,  DIMENSION(:    ), POINTER :: vli2
    INTEGER,  DIMENSION(:    ), POINTER :: vi_opp
    REAL(dp), DIMENSION(:    ), POINTER :: LI_xdy
    REAL(dp), DIMENSION(:    ), POINTER :: LI_mxydx
    REAL(dp), DIMENSION(:    ), POINTER :: LI_xydy
    INTEGER :: wn_tot, wn_max, wnV, wvli1, wvli2, wvi_opp, wLI_xdy, wLI_mxydx, wLI_xydy
  
  END TYPE type_remapping_conservative_intermediate_shared
  
  TYPE type_remapping_conservative
    ! Indices and weights for mapping data between two meshes, using 1st or 2nd order conservative remapping
    
    INTEGER,                    POINTER :: n_tot ! Total number of entries in list
    INTEGER,  DIMENSION(:    ), POINTER :: vli1  ! List index range per vertex
    INTEGER,  DIMENSION(:    ), POINTER :: vli2
    INTEGER,  DIMENSION(:    ), POINTER :: vi    ! Indices of vertices from mesh_src contributing to this mesh_dst vertex
    REAL(dp), DIMENSION(:    ), POINTER :: w0    ! Weights of vertices from mesh_src contributing to this mesh_dst vertex
    REAL(dp), DIMENSION(:    ), POINTER :: w1x   ! Weights of vertices from mesh_src contributing to this mesh_dst vertex
    REAL(dp), DIMENSION(:    ), POINTER :: w1y   ! Weights of vertices from mesh_src contributing to this mesh_dst vertex
    INTEGER :: wn_tot, wvli1, wvli2, wvi, ww0, ww1x, ww1y
    
  END TYPE type_remapping_conservative
  
  TYPE type_remapping
    ! Mapping index and weight arrays for remapping data between two meshes, for different remapping methods
    
    TYPE(type_remapping_trilin)                 :: trilin
    TYPE(type_remapping_nearest_neighbour)      :: nearest_neighbour
    TYPE(type_remapping_conservative)           :: conservative
  
  END TYPE type_remapping
  
  TYPE type_remapping_mesh2grid
    ! Indices and weights for mapping data between the model mesh and a grid using pseudo-conservative remapping
    
    ! Indices and weights
    INTEGER,                    POINTER :: n
    INTEGER,  DIMENSION(:,:  ), POINTER :: ii
    REAL(dp), DIMENSION(:    ), POINTER :: w_m2g
    REAL(dp), DIMENSION(:    ), POINTER :: w_g2m
    INTEGER :: wn, wii, ww_m2g, ww_g2m
  
  END TYPE type_remapping_mesh2grid
  
  TYPE type_grid
    ! A regular square grid covering a model region
    
    ! Basic grid data
    INTEGER,                    POINTER     :: nx, ny
    REAL(dp),                   POINTER     :: dx
    REAL(dp), DIMENSION(:    ), POINTER     :: x, y
    REAL(dp),                   POINTER     :: xmin, xmax, ymin, ymax
    INTEGER :: wnx, wny, wdx, wx, wy, wxmin, wxmax, wymin, wymax
    
    ! Parallelisation by domain decomposition
    INTEGER                                 :: i1, i2, j1, j2
    
    ! Mapping arrays between the grid and the model mesh (pseudo-conservative remapping)
    TYPE(type_remapping_mesh2grid)          :: map
    
    ! Lat-lon coordinates
    REAL(dp), DIMENSION(:,:  ), POINTER     :: lat, lon
    INTEGER :: wlat, wlon
  
  END TYPE type_grid
  
  TYPE type_remapping_latlon2mesh
    ! Indices and weights for mapping data from a global lat-lon grid to the model mesh using bilinear interpolation
    
    INTEGER,  DIMENSION(:    ), POINTER :: ilat1, ilat2, ilon1, ilon2
    REAL(dp), DIMENSION(:    ), POINTER :: wlat1, wlat2, wlon1, wlon2
    INTEGER :: wilat1, wilat2, wilon1, wilon2, wwlat1, wwlat2, wwlon1, wwlon2
    
  END TYPE type_remapping_latlon2mesh
  
  TYPE type_latlongrid
    ! A global lat-lon grid
    
    INTEGER,                    POINTER     :: nlat, nlon
    REAL(dp), DIMENSION(:    ), POINTER     :: lat, lon
    REAL(dp),                   POINTER     :: dlat, dlon
    INTEGER :: wnlat, wnlon, wlat, wlon, wdlat, wdlon
    
    INTEGER                                 :: i1, i2 ! Parallelisation by domain decomposition
    
  END TYPE type_latlongrid
  
  TYPE type_subclimate_global
    ! Global climate data, either from present-day observations (ERA40) or from a GCM snapshot.
    
    CHARACTER(LEN=256)                      :: name                          ! 'ERA40', 'HadCM3_PI', etc.
    
    ! NetCDF file containing the data
    TYPE(type_netcdf_climate_data)          :: netcdf
    
    ! Grid
    TYPE(type_latlongrid)                   :: grid
        
    ! General forcing info (not relevant for PD observations)
    REAL(dp),                   POINTER     :: CO2                           ! CO2 concentration in ppm that was used to force the GCM
    REAL(dp),                   POINTER     :: orbit_time                    ! The time (in ky ago) for the orbital forcing (Q_TOA can then be read from Laskar data)
    REAL(dp),                   POINTER     :: orbit_ecc                     ! Orbital parameters that were used to force the GCM
    REAL(dp),                   POINTER     :: orbit_obl
    REAL(dp),                   POINTER     :: orbit_pre
    INTEGER :: wCO2, worbit_time, worbit_ecc, worbit_obl, worbit_pre ! MPI windows to all these memory spaces
    
    ! Actual GCM data
    REAL(dp), DIMENSION(:,:,:), POINTER     :: T2m                           ! Monthly mean 2m air temperature (K)
    REAL(dp), DIMENSION(:,:,:), POINTER     :: Precip                        ! Monthly mean precipitation (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hs_ref                        ! Orography     that was used to force the GCM (m w.r.t. PD sea-level)
    REAL(dp), DIMENSION(:,:,:), POINTER     :: Wind_WE                       ! Monthly mean west-east wind speed (m/s)
    REAL(dp), DIMENSION(:,:,:), POINTER     :: Wind_SN                       ! Monthly mean south_north wind speed (m/s)
    INTEGER :: wT2m, wPrecip, wHs_ref, wWind_WE, wWind_SN ! MPI windows to all these memory spaces
  
  END TYPE type_subclimate_global
  
  TYPE type_ICE5G_timeframe
    ! Global ICE5G data, used to create reference orography for GCM snapshots so they can be downscaled to the model orography
    
    ! Time of the reconstruction
    REAL(dp)                                :: time        ! 0 for PD, -21000 for LGM
    
    ! NetCDF file containing the data
    TYPE(type_netcdf_ICE5G_data)            :: netcdf
    
    ! Grid
    TYPE(type_latlongrid)                   :: grid
    
    ! Data
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hi
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hb
    REAL(dp), DIMENSION(:,:  ), POINTER     :: mask_ice
    INTEGER :: wHi, wHb, wmask_ice
    
  END TYPE type_ICE5G_timeframe
  
  TYPE type_climate_matrix
    ! The climate matrix data structure. Contains all the different global GCM snapshots.
    
    ! The present-day observed climate (ERA40)
    TYPE(type_subclimate_global)            :: PD_obs
    
    ! The GCM snapshots.
    TYPE(type_subclimate_global)            :: GCM_PI
    TYPE(type_subclimate_global)            :: GCM_LGM 
    
    ! ICE5G data
    TYPE(type_ICE5G_timeframe)              :: ICE5G_PD
    TYPE(type_ICE5G_timeframe)              :: ICE5G_LGM 
  
  END TYPE type_climate_matrix
  
  TYPE type_subclimate_region
    ! Data from PD observations or a GCM snapshot, projected from their initial global grid onto the model region grid.
    
    CHARACTER(LEN=256)                      :: name                          ! 'ERA40', 'HadCM3_PI', etc.
        
    ! General forcing info (not relevant for PD observations)
    REAL(dp),                   POINTER     :: CO2                           ! CO2 concentration in ppm that was used to force the GCM
    REAL(dp),                   POINTER     :: orbit_time                    ! The time (in ky ago) for the orbital forcing (Q_TOA can then be read from Laskar data)
    REAL(dp),                   POINTER     :: orbit_ecc                     ! Orbital parameters that were used to force the GCM
    REAL(dp),                   POINTER     :: orbit_obl
    REAL(dp),                   POINTER     :: orbit_pre
    REAL(dp),                   POINTER     :: sealevel
    INTEGER :: wCO2, worbit_time, worbit_ecc, worbit_obl, worbit_pre, wsealevel
    
    ! Actual observed / GCM data (read from external NetCDF file)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: T2m                           ! Monthly mean 2m air temperature (K)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Precip                        ! Monthly mean precipitation (m)
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs_ref                        ! Orography      that was used to force the GCM (m w.r.t. PD sea-level) (coarse GCM resolution)
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi                            ! Ice thickness  that was used to force the GCM (m)
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb                            ! Bed topography that was used to force the GCM (m w.r.t. PD sea-level)
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs                            ! Orography      that was used to force the GCM (m w.r.t. PD sea-level) (fine   ISM resolution)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Wind_WE                       ! Monthly mean west-east   wind speed (m/s)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Wind_SN                       ! Monthly mean south-north wind speed (m/s)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Wind_LR                       ! Monthly mean wind speed in the x-direction (m/s)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Wind_DU                       ! Monthly mean wind speed in the y-direction (m/s)
    INTEGER :: wT2m, wPrecip, wHs_ref, wHi, wHb, wHs, wWind_WE, wWind_SN, wWind_LR, wWind_DU ! MPI windows to all these memory spaces
    
    ! Spatially variable lapse rate for GCM snapshots (see Berends et al., 2018)
    REAL(dp), DIMENSION(:    ), POINTER     :: lambda
    INTEGER :: wlambda
    
    ! Reference absorbed insolation (for GCM snapshots), or insolation at model time for the applied climate
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Q_TOA                         ! Monthly mean insolation at the top of the atmosphere (W/m2) (taken from the prescribed insolation solution at orbit_time)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Albedo                        ! Monthly mean surface albedo (calculated using our own SMB scheme for consistency)
    REAL(dp), DIMENSION(:    ), POINTER     :: I_abs                         ! Total yearly absorbed insolation, used in the climate matrix for interpolation
    REAL(dp),                   POINTER     :: Q_TOA_jun_65N, Q_TOA_jan_80S
    INTEGER :: wQ_TOA, wAlbedo, wI_abs, wQ_TOA_jun_65N, wQ_TOA_jan_80S
    
    ! Ocean temperature (parameterised right now)
    REAL(dp),                   POINTER     :: T_ocean_mean
    INTEGER :: wT_ocean_mean
  
  END TYPE type_subclimate_region
  
  TYPE type_climate_model
    ! All the relevant climate data fields (PD observations, GCM snapshots, and final, applied climate) on the mesh
    
    TYPE(type_subclimate_region)            :: PD_obs
    TYPE(type_subclimate_region)            :: GCM_PI
    TYPE(type_subclimate_region)            :: GCM_LGM
    TYPE(type_subclimate_region)            :: applied
    
    ! GCM bias
    REAL(dp), DIMENSION(:,:  ), POINTER     :: GCM_bias_T2m
    REAL(dp), DIMENSION(:,:  ), POINTER     :: GCM_bias_Precip
    INTEGER :: wGCM_bias_T2m, wGCM_bias_Precip
          
  END TYPE type_climate_model
  
  TYPE type_SMB_model
    ! The different SMB components, calculated from the prescribed climate
    
    ! Tuning parameters (different for each region, set from config)
    REAL(dp),                   POINTER     :: C_abl_constant
    REAL(dp),                   POINTER     :: C_abl_Ts
    REAL(dp),                   POINTER     :: C_abl_Q
    REAL(dp),                   POINTER     :: C_refr
    INTEGER :: wC_abl_constant, wC_abl_Ts, wC_abl_Q, wC_refr
    
    ! Data fields
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Q_TOA                         ! The prescribed monthly insolation, from an external forcing file
    REAL(dp), DIMENSION(:    ), POINTER     :: AlbedoSurf                    ! Surface albedo underneath the snow layer (water, rock or ice)
    REAL(dp), DIMENSION(:    ), POINTER     :: MeltPreviousYear              ! Total melt that occurred during the previous year (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: FirnDepth                     ! Depth of the firn layer (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Rainfall                      ! Monthly rainfall (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Snowfall                      ! Monthly snowfall (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: AddedFirn                     ! Monthly added firn (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Melt                          ! Monthly melt (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Refreezing                    ! Monthly refreezing (m)
    REAL(dp), DIMENSION(:    ), POINTER     :: Refreezing_year               ! Yearly  refreezing (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Runoff                        ! Monthly runoff (m)
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Albedo                        ! Monthly albedo
    REAL(dp), DIMENSION(:    ), POINTER     :: Albedo_year                   ! Yearly albedo
    REAL(dp), DIMENSION(:,:  ), POINTER     :: SMB                           ! Monthly SMB (m)
    REAL(dp), DIMENSION(:    ), POINTER     :: SMB_year                      ! Yearly  SMB (m)
    INTEGER :: wQ_TOA, wAlbedoSurf, wMeltPreviousYear, wFirnDepth, wRainfall, wSnowfall
    INTEGER :: wAddedFirn, wMelt, wRefreezing, wRefreezing_year, wRunoff, wAlbedo, wAlbedo_year, wSMB, wSMB_year
  
  END TYPE type_SMB_model
  
  TYPE type_BMB_model
    ! The different BMB components
    
    ! Tuning parameters (different for each region, set from config)
    REAL(dp),                   POINTER     :: T_ocean_mean_PD
    REAL(dp),                   POINTER     :: T_ocean_mean_cold
    REAL(dp),                   POINTER     :: T_ocean_mean_warm
    REAL(dp),                   POINTER     :: BMB_deepocean_PD
    REAL(dp),                   POINTER     :: BMB_deepocean_cold
    REAL(dp),                   POINTER     :: BMB_deepocean_warm
    REAL(dp),                   POINTER     :: BMB_shelf_exposed_PD
    REAL(dp),                   POINTER     :: BMB_shelf_exposed_cold
    REAL(dp),                   POINTER     :: BMB_shelf_exposed_warm
    REAL(dp),                   POINTER     :: subshelf_melt_factor
    REAL(dp),                   POINTER     :: deep_ocean_threshold_depth
    INTEGER :: wT_ocean_mean_PD, wT_ocean_mean_cold, wT_ocean_mean_warm
    INTEGER :: wBMB_deepocean_PD, wBMB_deepocean_cold, wBMB_deepocean_warm
    INTEGER :: wBMB_shelf_exposed_PD, wBMB_shelf_exposed_cold, wBMB_shelf_exposed_warm
    INTEGER :: wsubshelf_melt_factor, wdeep_ocean_threshold_depth
    
    ! Data fields
    REAL(dp), DIMENSION(:    ), POINTER     :: BMB                           ! The basal mass balance (same as SMB: negative means melt)
    REAL(dp), DIMENSION(:    ), POINTER     :: BMB_sheet                     ! The basal mass balance underneath the land-based ice sheet
    REAL(dp), DIMENSION(:    ), POINTER     :: BMB_shelf                     ! The basal mass balance underneath the floating   ice shelf
    REAL(dp), DIMENSION(:    ), POINTER     :: sub_angle                     ! "subtended angle"      for the sub-shelf melt parameterisation
    REAL(dp), DIMENSION(:    ), POINTER     :: dist_open                     ! distance to open ocean for the sub-shelf melt parameterisation
    INTEGER :: wBMB, wBMB_sheet, wBMB_shelf, wsub_angle, wdist_open
  
  END TYPE type_BMB_model
  
  TYPE type_PD_data_fields
    ! Data structure containing data fields describing the present-day world.
    
    ! NetCDF file containing the data
    TYPE(type_netcdf_PD_data)               :: netcdf
    
    ! Grid
    TYPE(type_grid)                         :: grid
    
    ! Data on the grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hi_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hb_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hs_grid
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_grid
    INTEGER :: wHi_grid, wHb_grid, wHs_grid, wmask_grid
    
    ! Data on the mesh
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs
    INTEGER,  DIMENSION(:    ), POINTER     :: mask
    INTEGER :: wHi, wHb, wHs, wmask
              
  END TYPE type_PD_data_fields
  
  TYPE type_init_data_fields
    ! Data structure containing data fields describing the present-day world.
    
    ! NetCDF file containing the data
    TYPE(type_netcdf_init_data)             :: netcdf
    TYPE(type_netcdf_restart)               :: netcdf_restart
    
    ! Grid
    TYPE(type_grid)                         :: grid
    
    ! Data on the grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hi_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hb_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Hs_grid
    REAL(dp), DIMENSION(:,:,:), POINTER     :: Ti_grid
    INTEGER :: wHi_grid, wHb_grid, wHs_grid, wTi_grid
    
    ! Derived data on the grid (needed for mesh generation)
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_grid
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_ice_grid
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_gl_grid
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_cf_grid
    INTEGER,  DIMENSION(:,:  ), POINTER     :: mask_coast_grid
    REAL(dp), DIMENSION(:,:  ), POINTER     :: surface_curvature_grid
    INTEGER :: wmask_grid, wmask_ice_grid, wmask_gl_grid, wmask_cf_grid, wmask_coast_grid, wsurface_curvature_grid
    
    ! Data on the mesh
    REAL(dp), DIMENSION(:    ), POINTER     :: Hi
    REAL(dp), DIMENSION(:    ), POINTER     :: Hb
    REAL(dp), DIMENSION(:    ), POINTER     :: Hs
    REAL(dp), DIMENSION(:,:  ), POINTER     :: Ti
    REAL(dp), DIMENSION(:    ), POINTER     :: U_SSA
    REAL(dp), DIMENSION(:    ), POINTER     :: V_SSA
    REAL(dp), DIMENSION(:    ), POINTER     :: MeltPreviousYear
    REAL(dp), DIMENSION(:,:  ), POINTER     :: FirnDepth
    INTEGER :: wHi, wHb, wHs, wTi, wU_SSA, wV_SSA, wMeltPreviousYear, wFirnDepth
              
  END TYPE type_init_data_fields
  
  TYPE type_forcing_data
    ! Data structure containing model forcing data - CO2 record, d18O record, (global) insolation record
    
    ! Data for the inverse routine
    REAL(dp),                   POINTER     :: dT_glob                                   ! Modelled global mean annual surface temperature anomaly w.r.t. PD
    REAL(dp), DIMENSION(:    ), POINTER     :: dT_glob_history                           ! Time window (length set in config) listing previous dT_glob values
    INTEGER,                    POINTER     :: ndT_glob_history                          ! Number of entries (= length of time window / dt_coupling)
    REAL(dp),                   POINTER     :: dT_deepwater                              ! Modelled deep-water temperature anomaly (= window averaged dT_glob * scaling factor), scaling factor set in config
    INTEGER :: wdT_glob, wdT_glob_history, wndT_glob_history, wdT_deepwater
    
    REAL(dp),                   POINTER     :: d18O_NAM, d18O_EAS, d18O_GRL, d18O_ANT    ! Modelled benthic d18O contributions from ice volume in the model regions
    REAL(dp),                   POINTER     :: d18O_from_ice_volume_mod                  ! Modelled benthic d18O contribution from global ice volume
    REAL(dp),                   POINTER     :: d18O_from_temperature_mod                 ! Modelled benthic d18O contribution from deep-water temperature change
    REAL(dp),                   POINTER     :: d18O_mod                                  ! Modelled benthic d18O
    INTEGER :: wd18O_NAM, wd18O_EAS, wd18O_GRL, wd18O_ANT, wd18O_from_ice_volume_mod, wd18O_from_temperature_mod, wd18O_mod
    
    REAL(dp),                   POINTER     :: dT_glob_inverse                           ! Global mean annual surface temperature anomaly resulting from the inverse method
    REAL(dp), DIMENSION(:    ), POINTER     :: dT_glob_inverse_history                   ! Time window (length set in config) listing previous dT_glob values
    INTEGER,                    POINTER     :: ndT_glob_inverse_history                  ! Number of entries (= length of time window / dt_coupling)
    REAL(dp),                   POINTER     :: CO2_inverse                               ! CO2 resulting from the inverse method
    REAL(dp), DIMENSION(:    ), POINTER     :: CO2_inverse_history                       ! Time window (length set in config) listing previous CO2_inverse values
    INTEGER,                    POINTER     :: nCO2_inverse_history                      ! Number of entries (= length of time window / dt_coupling)
    REAL(dp),                   POINTER     :: CO2_mod                                   ! Either equal to CO2_obs or to CO2_inverse, for easier writing to output.
    INTEGER :: wdT_glob_inverse, wdT_glob_inverse_history, wndT_glob_inverse_history, wCO2_inverse, wCO2_inverse_history, wnCO2_inverse_history, wCO2_mod
    
    ! External forcing: CO2 record
    REAL(dp), DIMENSION(:    ), POINTER     :: CO2_time
    REAL(dp), DIMENSION(:    ), POINTER     :: CO2_record
    REAL(dp),                   POINTER     :: CO2_obs
    INTEGER :: wCO2_time, wCO2_record, wCO2_obs
    
    ! External forcing: d18O record
    REAL(dp), DIMENSION(:    ), POINTER     :: d18O_time
    REAL(dp), DIMENSION(:    ), POINTER     :: d18O_record
    REAL(dp),                   POINTER     :: d18O_obs
    REAL(dp),                   POINTER     :: d18O_obs_PD
    INTEGER :: wd18O_time, wd18O_record, wd18O_obs, wd18O_obs_PD
    
    ! External forcing: insolation
    TYPE(type_netcdf_insolation)            :: netcdf_ins
    INTEGER,                    POINTER     :: ins_nyears
    INTEGER,                    POINTER     :: ins_nlat
    REAL(dp), DIMENSION(:    ), POINTER     :: ins_time
    REAL(dp), DIMENSION(:    ), POINTER     :: ins_lat
    REAL(dp),                   POINTER     :: ins_t0, ins_t1
    REAL(dp), DIMENSION(:,:  ), POINTER     :: ins_Q_TOA0, ins_Q_TOA1
    INTEGER :: wins_nyears, wins_nlat, wins_time, wins_lat, wins_t0, wins_t1, wins_Q_TOA0, wins_Q_TOA1
    
    ! External forcing: geothermal heat flux
    TYPE(type_netcdf_geothermal_heat_flux)  :: netcdf_ghf
    TYPE(type_latlongrid)                   :: grid_ghf
    REAL(dp), DIMENSION(:,:  ), POINTER     :: ghf_ghf
    INTEGER :: wghf_ghf
    
  END TYPE type_forcing_data
  
  TYPE type_model_region
    ! Contains all the different data structures, organised by sub-model (ice, climate)
    
    ! Metadata
    CHARACTER(LEN=3)                        :: name                  ! NAM, EAS, GRL, ANT
    CHARACTER(LEN=256)                      :: long_name             ! North America, Eurasia, Greenland, Antarctica
    
    ! Timers and switches for determining which modules need to be called at what points in time during the simulation
    REAL(dp)                                :: time                   ! The current time of this particular region.
    REAL(dp)                                :: dt, dt_prev            ! The (dynamic) time step    
    REAL(dp)                                :: dt_SIA                 ! The critical timestep following from the SIA ice velocities
    REAL(dp)                                :: dt_SSA                 ! The critical timestep following from the SSA ice velocities    
    REAL(dp)                                :: t0_SIA,     t1_SIA     ! Time of last and next update of SIA velocity
    REAL(dp)                                :: t0_SSA,     t1_SSA     !                                 SSA velocity
    REAL(dp)                                :: t0_thermo,  t1_Thermo  !                                 thermodynamics
    REAL(dp)                                :: t0_output,  t1_output  !                                 output file
    REAL(dp)                                :: t0_mesh,    t1_mesh    !                                 mesh
    REAL(dp)                                :: t0_climate, t1_climate !                                 climate
    REAL(dp)                                :: t0_SMB,     t1_SMB     !                                 SMB
    REAL(dp)                                :: t0_BMB,     t1_BMB     !                                 BMB
    REAL(dp)                                :: t0_ELRA,    t1_ELRA    !                                 ELRA bedrock deformation rates
    
    LOGICAL                                 :: do_solve_SIA
    LOGICAL                                 :: do_solve_SSA
    LOGICAL                                 :: do_thermodynamics
    LOGICAL                                 :: do_climate
    LOGICAL                                 :: do_SMB
    LOGICAL                                 :: do_BMB
    LOGICAL                                 :: do_write_output
    LOGICAL                                 :: do_ELRA
    
    ! Keep track of whether or not a NetCDF output file has been created (since we usually update the mesh more often than the output)
    LOGICAL                                 :: output_file_exists
    
    ! The region's ice sheet's volume and volume above flotation (in mSLE, so the second one is the ice sheets GMSL contribution)
    REAL(dp), POINTER                       :: ice_area
    REAL(dp), POINTER                       :: ice_volume
    REAL(dp), POINTER                       :: ice_volume_PD
    REAL(dp), POINTER                       :: ice_volume_above_flotation
    REAL(dp), POINTER                       :: ice_volume_above_flotation_PD
    REAL(dp), POINTER                       :: GMSL_contribution
    REAL(dp), POINTER                       :: mean_isotope_content
    REAL(dp), POINTER                       :: mean_isotope_content_PD
    REAL(dp), POINTER                       :: d18O_contribution
    REAL(dp), POINTER                       :: d18O_contribution_PD
    INTEGER :: wice_area, wice_volume, wice_volume_PD, wice_volume_above_flotation, wice_volume_above_flotation_PD, wGMSL_contribution
    INTEGER :: wmean_isotope_content, wmean_isotope_content_PD, wd18O_contribution, wd18O_contribution_PD
        
    ! Reference data fields
    TYPE(type_PD_data_fields)               :: PD               ! The present-day data fields for this model region, on a high-res Cartesian grid
    TYPE(type_init_data_fields)             :: init             ! The initial     data fields for this model region, on a high-res Cartesian grid
    
    ! Mask where ice is not allowed to form (so Greenland is not included in NAM and EAS, and Ellesmere is not included in GRL)
    INTEGER,  DIMENSION(:), POINTER         :: mask_noice
    INTEGER                                 :: wmask_noice
        
    ! Sub-models
    TYPE(type_mesh)                         :: mesh             ! The finite element mesh for this model region
    TYPE(type_mesh)                         :: mesh_new         ! The new mesh after updating (so that the old one can be kept until data has been mapped)
    TYPE(type_ice_model)                    :: ice              ! All the ice model data for this model region
    TYPE(type_climate_model)                :: climate          ! All the climate data for this model region
    TYPE(type_SMB_model)                    :: SMB              ! The different SMB components for this model region
    TYPE(type_BMB_model)                    :: BMB              ! The different BMB components for this model region
    
    ! Output netcdf files
    TYPE(type_netcdf_restart)               :: restart_mesh
    TYPE(type_netcdf_restart)               :: restart_grid
    TYPE(type_netcdf_help_fields)           :: help_fields_mesh
    TYPE(type_netcdf_help_fields)           :: help_fields_grid
    
    ! Different square grids
    TYPE(type_grid)                         :: grid_output      ! For the "_grid" output files
    TYPE(type_grid)                         :: grid_GIA         ! For either the ELRA model or SELEN
    TYPE(type_grid)                         :: grid_smooth      ! For smoothing data fields (used in the climate matrix)
    
    ! Computation times
    REAL(dp)                                :: tcomp_total
    REAL(dp)                                :: tcomp_mesh
    REAL(dp)                                :: tcomp_SIA
    REAL(dp)                                :: tcomp_SSA
    REAL(dp)                                :: tcomp_thermo
    REAL(dp)                                :: tcomp_climate
    REAL(dp)                                :: tcomp_output
    
  END TYPE type_model_region
  
  TYPE type_memory_use_tracker
  
    ! Memory use history
    INTEGER(KIND=MPI_ADDRESS_KIND)      :: total                     ! Total amount of allocated shared memory (in bytes)
    INTEGER                             :: n                         ! Number of entries
    INTEGER(KIND=MPI_ADDRESS_KIND), DIMENSION(:), ALLOCATABLE :: h   ! Memory use history over the past coupling interval
    
  END TYPE type_memory_use_tracker
  
CONTAINS

END MODULE data_types_module
