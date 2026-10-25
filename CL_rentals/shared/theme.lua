Theme = {}

-- Main accent (rental teal). Every highlight, ring and glow in the UI derives from this.
Theme.primaryColor  = '#2DD4BF'

Theme.success       = '#4ADE80'
Theme.danger        = '#F22933'
Theme.warning       = '#FFB347'
Theme.info          = '#47B5FF'

Theme.closeButtonBg = '#F22933'

-- Rental status colours (contracts, my rentals, admin)
Theme.status = {
    active      = '#2DD4BF',
    overdue     = '#FFB347',
    returned    = '#4ADE80',
    repossessed = '#F22933',
    lost        = '#F22933',
    ended       = '#9CA3AF',
    restart     = '#9CA3AF',
}

-- Marker drawn on the return zone while you drive a rental (r, g, b, a)
Theme.returnMarker = { 45, 212, 191, 90 }
