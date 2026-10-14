package com.zentrip.api;

import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class AdminControllerTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final AdminController controller = new AdminController(jdbc);

    @Test
    void dashboardRequiresAnAuthenticatedUser() {
        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> controller.dashboard(new MockHttpServletRequest()));

        assertEquals(401, exception.getStatusCode().value());
        verifyNoInteractions(jdbc);
    }

    @Test
    void dashboardRejectsCustomers() {
        when(jdbc.queryForObject("SELECT role FROM users WHERE id = ?", String.class, 7L))
                .thenReturn("customer");

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> controller.dashboard(authenticatedRequest()));

        assertEquals(403, exception.getStatusCode().value());
        verify(jdbc).queryForObject(
                "SELECT role FROM users WHERE id = ?", String.class, 7L);
    }

    @Test
    void dashboardReturnsLiveSummaryAndRecentReservationsForAdmins() {
        when(jdbc.queryForObject("SELECT role FROM users WHERE id = ?", String.class, 7L))
                .thenReturn("admin");
        Map<String, Object> summary = Map.of(
                "customer_count", 12L,
                "new_customers_30d", 3L,
                "reservation_count", 18L,
                "flight_count", 4L,
                "service_booking_count", 10L,
                "transfer_count", 4L,
                "booked_value", new BigDecimal("530.00"));
        List<Map<String, Object>> reservations = List.of(
                Map.of("id", "booking-5", "type", "hotel", "amount", new BigDecimal("120.00")));
        when(jdbc.queryForMap(any(String.class))).thenReturn(summary);
        when(jdbc.queryForList(any(String.class), eq(8))).thenReturn(reservations);

        Map<String, Object> response = controller.dashboard(authenticatedRequest());

        assertEquals(summary, response.get("summary"));
        assertEquals(reservations, response.get("recent_reservations"));
    }

    @Test
    void customerListRejectsOutOfRangeLimit() {
        when(jdbc.queryForObject("SELECT role FROM users WHERE id = ?", String.class, 7L))
                .thenReturn("admin");

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> controller.customers(101, authenticatedRequest()));

        assertEquals(400, exception.getStatusCode().value());
        verify(jdbc).queryForObject(
                "SELECT role FROM users WHERE id = ?", String.class, 7L);
    }

    private static HttpServletRequest authenticatedRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute("authUserId", 7L);
        return request;
    }
}
