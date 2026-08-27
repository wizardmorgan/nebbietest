<?php
/**
 * Plugin Name: Nebbie Edit Portal SSO
 * Description: Link firmato HMAC verso il Portale Edit (/edit/) per utenti WordPress loggati.
 * Author: Nebbie Arcane
 *
 * Installazione: copia in wp-content/mu-plugins/ (must-use: attivo senza attivazione).
 *
 * wp-config.php (stesso secret del container edit-portal):
 *   define('NEBBIE_EDIT_SSO_SECRET', '…');           // = EDIT_WP_SSO_SECRET
 *   define('NEBBIE_EDIT_PORTAL_URL', 'https://www.nebbiearcane.it/edit');
 *   // opzionale:
 *   // define('NEBBIE_EDIT_SSO_TTL', 120);
 *   // define('NEBBIE_EDIT_MENU_LABEL', 'Portale Edit');
 *
 * Flusso: utente WP loggato → link con token → GET /edit/api/sso/wordpress?token=…
 * L'email WP deve coincidere con user.email nel MySQL Mud.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * @return string
 */
function nebbie_edit_sso_secret() {
    if (defined('NEBBIE_EDIT_SSO_SECRET') && NEBBIE_EDIT_SSO_SECRET) {
        return (string) NEBBIE_EDIT_SSO_SECRET;
    }
    return (string) getenv('NEBBIE_EDIT_SSO_SECRET');
}

/**
 * Base URL del portale (senza slash finale), es. https://www.nebbiearcane.it/edit
 * @return string
 */
function nebbie_edit_portal_base() {
    if (defined('NEBBIE_EDIT_PORTAL_URL') && NEBBIE_EDIT_PORTAL_URL) {
        return rtrim((string) NEBBIE_EDIT_PORTAL_URL, '/');
    }
    $env = getenv('NEBBIE_EDIT_PORTAL_URL');
    if ($env) {
        return rtrim((string) $env, '/');
    }
    return home_url('/edit');
}

/**
 * @param string $data
 * @return string
 */
function nebbie_edit_b64url($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/**
 * @param string $email
 * @param int    $ttl
 * @return string|WP_Error
 */
function nebbie_edit_mint_sso_token($email, $ttl = null) {
    $secret = nebbie_edit_sso_secret();
    if ($secret === '') {
        return new WP_Error('nebbie_edit_sso', 'NEBBIE_EDIT_SSO_SECRET non configurato');
    }
    $email = strtolower(trim((string) $email));
    if ($email === '' || strpos($email, '@') === false) {
        return new WP_Error('nebbie_edit_sso', 'email utente non valida');
    }
    if ($ttl === null) {
        $ttl = defined('NEBBIE_EDIT_SSO_TTL') ? (int) NEBBIE_EDIT_SSO_TTL : 120;
    }
    $ttl = max(30, min(300, (int) $ttl));
    $now = time();
    $payload = wp_json_encode(
        array(
            'email' => $email,
            'iat'   => $now,
            'exp'   => $now + $ttl,
        )
    );
    $payload_b64 = nebbie_edit_b64url($payload);
    $sig = hash_hmac('sha256', $payload_b64, $secret, true);
    return $payload_b64 . '.' . nebbie_edit_b64url($sig);
}

/**
 * URL completo SSO (redirect al portale).
 *
 * @param WP_User|null $user
 * @return string|WP_Error
 */
function nebbie_edit_sso_url($user = null) {
    if (!$user) {
        $user = wp_get_current_user();
    }
    if (!$user || !$user->ID) {
        return new WP_Error('nebbie_edit_sso', 'login WordPress richiesto');
    }
    $token = nebbie_edit_mint_sso_token($user->user_email);
    if (is_wp_error($token)) {
        return $token;
    }
    return nebbie_edit_portal_base() . '/api/sso/wordpress?token=' . rawurlencode($token);
}

/**
 * Shortcode: [nebbie_edit_portal] — bottone/link per utenti loggati.
 */
function nebbie_edit_shortcode_portal($atts = array()) {
    $atts = shortcode_atts(
        array(
            'label' => defined('NEBBIE_EDIT_MENU_LABEL')
                ? NEBBIE_EDIT_MENU_LABEL
                : 'Apri Portale Edit',
            'class' => 'nebbie-edit-portal-link',
        ),
        $atts,
        'nebbie_edit_portal'
    );

    if (!is_user_logged_in()) {
        $login = wp_login_url(get_permalink());
        return '<p class="' . esc_attr($atts['class']) . '"><a href="' . esc_url($login) . '">Accedi al sito</a> per aprire il Portale Edit.</p>';
    }

    $url = nebbie_edit_sso_url();
    if (is_wp_error($url)) {
        if (current_user_can('manage_options')) {
            return '<p class="nebbie-edit-sso-error">' . esc_html($url->get_error_message()) . '</p>';
        }
        return '';
    }

    return '<p class="' . esc_attr($atts['class']) . '"><a class="button" href="' . esc_url($url) . '">' . esc_html($atts['label']) . '</a></p>';
}
add_shortcode('nebbie_edit_portal', 'nebbie_edit_shortcode_portal');

/**
 * Voce admin bar per utenti loggati.
 */
function nebbie_edit_admin_bar($wp_admin_bar) {
    if (!is_user_logged_in() || !nebbie_edit_sso_secret()) {
        return;
    }
    $url = nebbie_edit_sso_url();
    if (is_wp_error($url)) {
        return;
    }
    $label = defined('NEBBIE_EDIT_MENU_LABEL') ? NEBBIE_EDIT_MENU_LABEL : 'Portale Edit';
    $wp_admin_bar->add_node(
        array(
            'id'    => 'nebbie-edit-portal',
            'title' => $label,
            'href'  => $url,
            'meta'  => array('target' => '_self'),
        )
    );
}
add_action('admin_bar_menu', 'nebbie_edit_admin_bar', 80);

/**
 * Redirect dedicato: /?nebbie_edit_sso=1 (utile da menu WP).
 */
function nebbie_edit_query_redirect() {
    if (!isset($_GET['nebbie_edit_sso'])) {
        return;
    }
    if (!is_user_logged_in()) {
        auth_redirect();
        exit;
    }
    $url = nebbie_edit_sso_url();
    if (is_wp_error($url)) {
        wp_die(esc_html($url->get_error_message()), 'Portale Edit SSO', array('response' => 500));
    }
    wp_redirect($url);
    exit;
}
add_action('template_redirect', 'nebbie_edit_query_redirect', 1);
