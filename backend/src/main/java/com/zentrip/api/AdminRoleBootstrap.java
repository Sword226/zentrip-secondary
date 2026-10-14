package com.zentrip.api;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Component
public class AdminRoleBootstrap implements ApplicationRunner {
    private final JdbcTemplate jdbc;
    private final String adminEmail;
    private final String partnerAccounts;

    public AdminRoleBootstrap(
            JdbcTemplate jdbc,
            @Value("${app.admin.email:}") String adminEmail,
            @Value("${app.partner.accounts:}") String partnerAccounts) {
        this.jdbc = jdbc;
        this.adminEmail = adminEmail.trim();
        this.partnerAccounts = partnerAccounts.trim();
    }

    @Override
    public void run(ApplicationArguments args) {
        ensureColumnExists("users", "role",
                "ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'customer'");
        ensureColumnExists("users", "partner_id",
                "ALTER TABLE users ADD COLUMN partner_id BIGINT NULL");
        ensureColumnExists("trips", "partner_id",
                "ALTER TABLE trips ADD COLUMN partner_id BIGINT NULL");
        ensureColumnExists("trips", "partner_listing_id",
                "ALTER TABLE trips ADD COLUMN partner_listing_id BIGINT NULL");
        ensureColumnExists("bookings", "partner_id",
                "ALTER TABLE bookings ADD COLUMN partner_id BIGINT NULL");
        ensureColumnExists("bookings", "partner_listing_id",
                "ALTER TABLE bookings ADD COLUMN partner_listing_id BIGINT NULL");
        ensureColumnExists("transfers", "partner_id",
                "ALTER TABLE transfers ADD COLUMN partner_id BIGINT NULL");
        ensureColumnExists("transfers", "partner_listing_id",
                "ALTER TABLE transfers ADD COLUMN partner_listing_id BIGINT NULL");

        List<PartnerAccount> accounts = parsePartnerAccounts();
        if (accounts.stream().anyMatch(
                account -> account.email().equalsIgnoreCase(adminEmail))) {
            throw new IllegalStateException(
                    "An email cannot be configured as both Zentrip admin and partner.");
        }
        validatePartnerAccounts(accounts);
        if (!adminEmail.isBlank()) promoteAdmin();
        revokeUnconfiguredPartners(accounts);
        configurePartners(accounts);
    }

    private void promoteAdmin() {
        Integer matchingUsers = jdbc.queryForObject(
                "SELECT COUNT(*) FROM users WHERE email = ?",
                Integer.class,
                adminEmail);
        if (matchingUsers == null || matchingUsers == 0) {
            throw new IllegalStateException(
                    "APP_ADMIN_EMAIL must match an existing Zentrip user account.");
        }
        jdbc.update(
                "UPDATE users SET role = 'admin', partner_id = NULL WHERE email = ?",
                adminEmail);
    }

    private List<PartnerAccount> parsePartnerAccounts() {
        if (partnerAccounts.isBlank()) return List.of();
        return Arrays.stream(partnerAccounts.split(";"))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(PartnerAccount::parse)
                .toList();
    }

    private void validatePartnerAccounts(List<PartnerAccount> accounts) {
        for (PartnerAccount account : accounts) {
            Integer matchingUsers = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM users WHERE email = ?",
                    Integer.class,
                    account.email());
            if (matchingUsers == null || matchingUsers == 0) {
                throw new IllegalStateException(
                        "Configured partner email must match an existing Zentrip user: "
                                + account.email());
            }
        }
    }

    private void revokeUnconfiguredPartners(List<PartnerAccount> accounts) {
        jdbc.update(
                "UPDATE users SET role = 'customer', partner_id = NULL WHERE role = 'partner'");
        if (accounts.isEmpty()) {
            jdbc.update("UPDATE partners SET status = 'inactive'");
            return;
        }
        String placeholders = accounts.stream()
                .map(account -> "?")
                .collect(Collectors.joining(", "));
        jdbc.update(
                "UPDATE partners SET status = 'inactive' WHERE slug NOT IN ("
                        + placeholders + ")",
                accounts.stream().map(PartnerAccount::slug).toArray());
    }

    private void configurePartners(List<PartnerAccount> accounts) {
        for (PartnerAccount account : accounts) {
            jdbc.update("""
                    INSERT INTO partners (slug, name, service_type, status)
                    VALUES (?, ?, ?, 'active')
                    ON DUPLICATE KEY UPDATE
                        name = VALUES(name), service_type = VALUES(service_type), status = 'active'
                    """, account.slug(), account.name(), account.serviceType());
            Long partnerId = jdbc.queryForObject(
                    "SELECT id FROM partners WHERE slug = ?",
                    Long.class,
                    account.slug());
            jdbc.update(
                    "UPDATE users SET role = 'partner', partner_id = ? WHERE email = ?",
                    partnerId,
                    account.email());
        }
    }

    private void ensureColumnExists(String table, String column, String alterSql) {
        Integer columnCount = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = ?
                  AND COLUMN_NAME = ?
                """, Integer.class, table, column);
        if (columnCount == null || columnCount == 0) {
            jdbc.execute(alterSql);
        }
    }

    private record PartnerAccount(
            String email, String slug, String name, String serviceType) {
        private static PartnerAccount parse(String entry) {
            String[] fields = entry.split("\\|", -1);
            if (fields.length != 4) {
                throw new IllegalStateException(
                        "APP_PARTNER_ACCOUNTS entries must use email|slug|name|service-type.");
            }
            String email = fields[0].trim().toLowerCase(Locale.ROOT);
            String slug = fields[1].trim().toLowerCase(Locale.ROOT);
            String name = fields[2].trim();
            String serviceType = fields[3].trim().toLowerCase(Locale.ROOT);
            if (email.isBlank() || !email.contains("@") || slug.isBlank() || name.isBlank()
                    || !List.of("airline", "hotel", "car", "attraction", "transfer", "travel")
                            .contains(serviceType)) {
                throw new IllegalStateException(
                        "APP_PARTNER_ACCOUNTS contains an invalid account, company, or service type.");
            }
            return new PartnerAccount(email, slug, name, serviceType);
        }
    }
}
