<?php
/**
 * Plugin Name: ICEX Atlas · Claims de membresía y sincronía
 * Description: Añade el claim icex_member_verified (y promoción/fase) al ID token del plugin
 *              «OpenID Connect Server» y expone el endpoint de sincronía de bajas para ICEX Atlas.
 * Version:     1.0.0
 * Requires PHP: 8.1
 *
 * Instalación: ver wordpress/README.md. Copiar a wp-content/mu-plugins/icex-atlas-oidc.php
 * (must-use: no se puede desactivar por error desde el escritorio).
 *
 * ⚠ ADAPTAR: la función icex_atlas_is_active_member() debe consultar cómo marca la web de
 *   ICEX Alumni a sus socios al corriente (rol, plugin de membresías, meta de usuario…).
 */

defined( 'ABSPATH' ) || exit;

/** Rol o capacidad que identifica a un socio verificado y al corriente. */
const ICEX_ATLAS_MEMBER_ROLE = 'socio_icex_alumni';

/**
 * ¿Es socio activo? Ajustar a la implementación real de la web.
 * Ejemplos habituales:
 *   - Rol de WordPress:            in_array( ICEX_ATLAS_MEMBER_ROLE, $user->roles, true )
 *   - Paid Memberships Pro:        pmpro_hasMembershipLevel( null, $user->ID )
 *   - MemberPress:                 ( new MeprUser( $user->ID ) )->is_active()
 *   - Meta de usuario propia:      get_user_meta( $user->ID, 'icex_socio_activo', true ) === '1'
 */
function icex_atlas_is_active_member( WP_User $user ): bool {
	$active = in_array( ICEX_ATLAS_MEMBER_ROLE, (array) $user->roles, true );
	return (bool) apply_filters( 'icex_atlas_is_active_member', $active, $user );
}

/** Promoción (1-99) y fase (fase_0|fase_1|fase_2|activo) si la web las guarda como metadatos. */
function icex_atlas_member_profile( WP_User $user ): array {
	$promo = (int) get_user_meta( $user->ID, 'icex_promocion', true );
	$fase  = (string) get_user_meta( $user->ID, 'icex_fase', true );
	$out   = array();
	if ( $promo >= 1 && $promo <= 99 ) {
		$out['icex_promocion'] = $promo;
	}
	if ( in_array( $fase, array( 'fase_0', 'fase_1', 'fase_2', 'activo' ), true ) ) {
		$out['icex_fase'] = $fase;
	}
	return $out;
}

/**
 * Filtro del plugin OpenID Connect Server (Automattic): claims del ID token / userinfo.
 * Supabase Auth solo conserva los claims de su custom_claims_allowlist
 * (icex_member_verified, icex_promocion, icex_fase) → ver docs/runbook.md.
 */
add_filter(
	'oidc_user_claims',
	static function ( array $claims, WP_User $user ): array {
		$claims['name']                 = $user->display_name;
		$claims['icex_member_verified'] = icex_atlas_is_active_member( $user );
		return array_merge( $claims, icex_atlas_member_profile( $user ) );
	},
	10,
	2
);

/**
 * Endpoint de sincronía diaria (Edge Function membership-sync):
 *   POST /wp-json/icex-alumni/v1/memberships
 *   Authorization: Bearer <ICEX_ATLAS_SYNC_TOKEN>
 *   { "subjects": ["<sub>", ...] }   (máx. 1000)
 *   → { "memberships": { "<sub>": "active" | "inactive" | "unknown" } }
 *
 * El `sub` que emite OpenID Connect Server es el user_login (comportamiento por defecto).
 * Definir en wp-config.php:  define( 'ICEX_ATLAS_SYNC_TOKEN', '<token largo aleatorio>' );
 */
add_action(
	'rest_api_init',
	static function (): void {
		register_rest_route(
			'icex-alumni/v1',
			'/memberships',
			array(
				'methods'             => 'POST',
				'permission_callback' => static function ( WP_REST_Request $req ): bool {
					if ( ! defined( 'ICEX_ATLAS_SYNC_TOKEN' ) || strlen( ICEX_ATLAS_SYNC_TOKEN ) < 32 ) {
						return false;
					}
					$auth = (string) $req->get_header( 'authorization' );
					return hash_equals( 'Bearer ' . ICEX_ATLAS_SYNC_TOKEN, $auth );
				},
				'callback'            => static function ( WP_REST_Request $req ): WP_REST_Response {
					$subjects = $req->get_json_params()['subjects'] ?? array();
					if ( ! is_array( $subjects ) ) {
						return new WP_REST_Response( array( 'error' => 'subjects' ), 400 );
					}
					$result = array();
					foreach ( array_slice( $subjects, 0, 1000 ) as $sub ) {
						$sub  = sanitize_user( (string) $sub, true );
						$user = get_user_by( 'login', $sub );
						if ( ! $user ) {
							$result[ $sub ] = 'unknown';   // «unknown» nunca revoca (freno de seguridad)
							continue;
						}
						$result[ $sub ] = icex_atlas_is_active_member( $user ) ? 'active' : 'inactive';
					}
					return new WP_REST_Response( array( 'memberships' => $result ), 200 );
				},
			)
		);
	}
);
