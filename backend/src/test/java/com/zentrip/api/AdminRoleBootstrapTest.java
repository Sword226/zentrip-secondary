package com.zentrip.api;

import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationArguments;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminRoleBootstrapTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final ApplicationArguments args = mock(ApplicationArguments.class);

    @Test
    void promotesOnlyTheConfiguredExistingAccount() {
        when(jdbc.queryForObject(
                contains("information_schema.COLUMNS"),
                eq(Integer.class),
                anyString(),
                anyString()))
                .thenReturn(1);
        when(jdbc.queryForObject(
                "SELECT COUNT(*) FROM users WHERE email = ?",
                Integer.class,
                "admin@example.com"))
                .thenReturn(1);

        new AdminRoleBootstrap(jdbc, "admin@example.com", "").run(args);

        verify(jdbc).update(
                "UPDATE users SET role = 'admin', partner_id = NULL WHERE email = ?",
                "admin@example.com");
        verify(jdbc).update("UPDATE users SET role = 'customer', partner_id = NULL WHERE role = 'partner'");
        verify(jdbc).update("UPDATE partners SET status = 'inactive'");
    }

    @Test
    void failsClearlyWhenConfiguredAdminAccountDoesNotExist() {
        when(jdbc.queryForObject(
                contains("information_schema.COLUMNS"),
                eq(Integer.class),
                anyString(),
                anyString()))
                .thenReturn(1);
        when(jdbc.queryForObject(
                "SELECT COUNT(*) FROM users WHERE email = ?",
                Integer.class,
                "missing@example.com"))
                .thenReturn(0);

        assertThrows(
                IllegalStateException.class,
                () -> new AdminRoleBootstrap(jdbc, "missing@example.com", "").run(args));

        verify(jdbc, never()).update(
                "UPDATE users SET role = 'admin', partner_id = NULL WHERE email = ?",
                "missing@example.com");
    }

    @Test
    void promotesOnlyConfiguredPartnerAndDeactivatesRemovedCompanies() {
        when(jdbc.queryForObject(
                contains("information_schema.COLUMNS"),
                eq(Integer.class),
                anyString(),
                anyString()))
                .thenReturn(1);
        when(jdbc.queryForObject(
                "SELECT COUNT(*) FROM users WHERE email = ?",
                Integer.class,
                "libyanwings@zentrip.ly"))
                .thenReturn(1);
        when(jdbc.queryForObject(
                "SELECT id FROM partners WHERE slug = ?",
                Long.class,
                "libyan-wings"))
                .thenReturn(8L);

        new AdminRoleBootstrap(
                jdbc,
                "",
                "libyanwings@zentrip.ly|libyan-wings|Libyan Wings|airline")
                .run(args);

        verify(jdbc).update(
                "UPDATE users SET role = 'customer', partner_id = NULL WHERE role = 'partner'");
        verify(jdbc).update(
                "UPDATE partners SET status = 'inactive' WHERE slug NOT IN (?)",
                "libyan-wings");
        verify(jdbc).update(
                "UPDATE users SET role = 'partner', partner_id = ? WHERE email = ?",
                8L,
                "libyanwings@zentrip.ly");
    }

    @Test
    void rejectsUnregisteredPartnerWithoutChangingExistingRoles() {
        when(jdbc.queryForObject(
                contains("information_schema.COLUMNS"),
                eq(Integer.class),
                anyString(),
                anyString()))
                .thenReturn(1);
        when(jdbc.queryForObject(
                "SELECT COUNT(*) FROM users WHERE email = ?",
                Integer.class,
                "missing@zentrip.ly"))
                .thenReturn(0);

        assertThrows(
                IllegalStateException.class,
                () -> new AdminRoleBootstrap(
                        jdbc,
                        "",
                        "missing@zentrip.ly|missing|Missing|hotel").run(args));

        verify(jdbc, never()).update(contains("UPDATE users SET role = 'customer'"));
    }
}
