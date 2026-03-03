/**
 * shared.js - Fixed Version
 * Handles: Header/Footer Injection, Grid Menu, Theme Toggle, Link Correction
 */

document.addEventListener('DOMContentLoaded', async () => {
    'use strict';

    // --- CONFIGURATION ---
    
    const getPath = (filename) => {
        const isSubDir = window.location.pathname.includes('/ukhona/html/');
        const prefix = isSubDir ? '../html/' : 'ukhona/html/';
        return `${prefix}${filename}`;
    };

    const REPO_NAME = '/repos-00';
    const BASE = window.location.pathname.startsWith(REPO_NAME) ? REPO_NAME : '';

    const fixLinks = (container) => {
        if (!container || !BASE) return;
        const links = container.querySelectorAll('a[href^="/"]');
        links.forEach(a => {
            const href = a.getAttribute('href');
            if (!href.startsWith(BASE)) {
                a.setAttribute('href', `${BASE}${href}`);
            }
        });
    };

    // --- INJECTION ENGINE (WITH ERROR FEEDBACK) ---
    async function inject(id, filename) {
        const placeholder = document.getElementById(id);
        if (!placeholder) {
            console.error(`[System] Element #${id} not found`);
            return;
        }

        try {
            const response = await fetch(getPath(filename));
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            const data = await response.text();
            placeholder.innerHTML = data;
            fixLinks(placeholder);
            console.log(`[System] ✓ Injected: ${filename}`);
        } catch (err) {
            console.error(`[System] ✗ Failed to inject ${filename}:`, err);
            placeholder.innerHTML = `<div style="color:red;padding:1rem;">Failed to load ${filename}</div>`;
        }
    }

    // --- LOAD PARTIALS ---
    const PARTIALS = [
        ['header', 'header.html'],
        ['footer-placeholder', 'footer.html']
    ];

    await Promise.all(PARTIALS.map(([id, file]) => inject(id, file)));

    // --- INITIALIZE COMPONENTS ---
    initGridMenu();
    initThemeToggle();
    initScrollProgress();
    initFooterChorus(); 

    // --- GRID MENU (FIXED CLICK HANDLING) ---
    function initGridMenu() {
        const menuBtn = document.getElementById('menuIcon');
        const menuGrid = document.getElementById('gridMenu');

        if (!menuBtn || !menuGrid) return;

        fixLinks(menuGrid);

        let isOpen = false;

        const openMenu = () => {
            isOpen = true;
            menuGrid.classList.add('active');
            menuBtn.setAttribute('aria-expanded', 'true');
        };

        const closeMenu = () => {
            isOpen = false;
            menuGrid.classList.remove('active');
            menuBtn.setAttribute('aria-expanded', 'false');
        };

        // Toggle on button click
        menuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            isOpen ? closeMenu() : openMenu();
        });

        // Close on outside click (capture phase to catch early)
        document.addEventListener('click', (e) => {
            if (isOpen && !menuGrid.contains(e.target) && !menuBtn.contains(e.target)) {
                closeMenu();
            }
        }, true);

        // Close on Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && isOpen) {
                closeMenu();
            }
        });
    }

    // --- THEME TOGGLE ---
    function initThemeToggle() {
        const themeBtn = document.getElementById('toggle-theme');
        const logo = document.getElementById('logo');
        const savedTheme = localStorage.getItem('theme') || 'dark';
        
        document.documentElement.setAttribute('data-theme', savedTheme);

        // Update logo for initial theme
        if (logo) {
            const lightSrc = logo.getAttribute('data-light-src');
            const darkSrc = logo.getAttribute('data-dark-src');
            logo.src = savedTheme === 'dark' ? darkSrc : lightSrc;
        }

        if (themeBtn) {
            themeBtn.textContent = savedTheme === 'dark' ? '🌙' : '☀️';
            
            themeBtn.addEventListener('click', () => {
                const currentTheme = document.documentElement.getAttribute('data-theme');
                const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
                
                document.documentElement.setAttribute('data-theme', newTheme);
                localStorage.setItem('theme', newTheme);
                themeBtn.textContent = newTheme === 'dark' ? '🌙' : '☀️';
                
                // Switch logo
                if (logo) {
                    const lightSrc = logo.getAttribute('data-light-src');
                    const darkSrc = logo.getAttribute('data-dark-src');
                    logo.src = newTheme === 'dark' ? darkSrc : lightSrc;
                }
            });
        }
    }

    // --- SCROLL PROGRESS (DEBOUNCED) ---
    function initScrollProgress() {
        const progress = document.querySelector('.scroll-progress');
        if (!progress) return;

        let ticking = false;

        window.addEventListener('scroll', () => {
            if (!ticking) {
                window.requestAnimationFrame(() => {
                    const winScroll = document.body.scrollTop || document.documentElement.scrollTop;
                    const height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
                    const scrolled = (winScroll / height) * 100;
                    progress.style.width = scrolled + "%";
                    ticking = false;
                });
                ticking = true;
            }
        });
    }

    // --- FOOTER CHORUS ---
    function initFooterChorus() {
        const box = document.querySelector('.rotating-chorus');
        if (!box) return;
        
        const chips = Array.from(box.querySelectorAll('.chip'));
        if (chips.length === 0) return;

        let currentIndex = 0;
        chips.forEach((chip, idx) => chip.style.display = idx === 0 ? 'inline' : 'none');

        if (window.chorusInterval) clearInterval(window.chorusInterval);
        
        window.chorusInterval = setInterval(() => {
            chips[currentIndex].style.display = 'none';
            currentIndex = (currentIndex + 1) % chips.length;
            chips[currentIndex].style.display = 'inline';
        }, 5000);
    }
});