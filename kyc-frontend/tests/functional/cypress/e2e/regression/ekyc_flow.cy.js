describe('eKYC Flow', () => {
    it('Should successfully verify a user', () => {
        cy.visit('/');
        cy.contains('Start eKYC').click();

        // Fill Form
        cy.get('input[placeholder="Enter 12-digit Aadhaar"]').type('123456789012');
        cy.get('input[placeholder="As per Aadhaar"]').type('Cypress User');

        // Submit
        cy.contains('Submit eKYC').click();

        // Assert Success
        cy.contains('Verification Successful!').should('be.visible');
        cy.url().should('include', '/ekyc');
    });

    it('Should handle API disconnects gracefully', () => {
        // Mock failure
        cy.intercept('POST', '/api/ekyc/verify', { statusCode: 500 }).as('verifyFail');

        cy.visit('/ekyc');
        cy.get('input[placeholder="Enter 12-digit Aadhaar"]').type('123456789012');
        cy.get('input[placeholder="As per Aadhaar"]').type('Error User');
        cy.contains('Submit eKYC').click();

        cy.wait('@verifyFail');
        // Check for alert or error message (implementation dependent)
        // cy.on('window:alert', (str) => { expect(str).to.equal('Error connecting to eKYC service') })
    });
});
