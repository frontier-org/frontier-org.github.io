const CONFIG = {
    repoBase: "https://raw.githubusercontent.com/frontier-org/frontier/main/",
    defaultFile: "README.md",
    navbarHeight: 90 
};

const DOCS_WHITELIST = ["README.md", "LOGS.md", "MANUAL.md", "ROADMAP.md"];

const renderer = {
    heading(token) {
        const text = token.text;
        const depth = token.depth;
        const slug = text.toLowerCase()
            .replace(/<[^>]*>/g, '') 
            .replace(/[^\w\s-]/g, '') 
            .replace(/\s/g, '-');
        return `<h${depth} id="${slug}">${this.parser.parseInline(token.tokens)}</h${depth}>`;
    },

    link(token) {
        const href = token.href;
        const text = this.parser.parseInline(token.tokens);
        if (href.startsWith('http')) return `<a href="${href}" target="_blank" rel="noopener">${text}</a>`;
        if (href.endsWith('.md') || href.includes('.md#')) {
            const [file, anchor] = href.replace('./', '').split('#');
            if (DOCS_WHITELIST.includes(file)) return `<a href="./?${file}${anchor ? '#' + anchor : ''}">${text}</a>`;
        }
        return `<a href="${href}">${text}</a>`;
    },

    image(token) {
        let href = token.href;
        const text = token.text;

        if (href.includes('shields.io')) {
            const separator = href.includes('?') ? '&' : '?';
            
            href = `${href}${separator}style=flat-square&color=06b6d4`;
            
            return `<img src="${href}" alt="${text}" class="badge-cyber">`;
        }

        const finalSrc = href.startsWith('http') ? href : `${CONFIG.repoBase}${href.replace('./', '')}`;
        return `<img src="${finalSrc}" alt="${text}" class="rounded-xl border border-white/10 my-10 shadow-2xl max-w-full mx-auto block">`;
    }
};

marked.use({ renderer });

async function loadContent() {
    const queryString = window.location.search.substring(1);
    const fileName = queryString.split('#')[0] || CONFIG.defaultFile;
    const targetFile = fileName.startsWith('./') ? fileName.substring(2) : fileName;
    const contentEl = document.getElementById('content');
    const headerEl = document.getElementById('doc-header');
    const loadingBody = document.getElementById('loading-body');

    try {
        if (!DOCS_WHITELIST.includes(targetFile)) throw new Error("UNAUTHORIZED");
        const response = await fetch(`${CONFIG.repoBase}${targetFile}?t=${Date.now()}`);
        if (!response.ok) throw new Error("404");
        const markdown = await response.text();
        contentEl.innerHTML = marked.parse(markdown);

        const firstH1 = contentEl.querySelector('h1');
        if (firstH1) {
            headerEl.innerHTML = `
                <div class="text-cyan-500 font-bold text-sm tracking-widest uppercase mb-4 flex items-center gap-2">
                    <i class="fas fa-file-alt"></i> docs / ${targetFile}
                </div>
                <h1 class="text-5xl md:text-7xl font-black tracking-tighter text-white">${firstH1.innerHTML}</h1>
            `;
            firstH1.remove();
        }

        contentEl.querySelectorAll('pre code').forEach(el => hljs.highlightElement(el));
        loadingBody.classList.add('hidden');
        contentEl.classList.remove('hidden');
        document.title = `Frontier | ${targetFile}`;
        
        if (window.location.hash) {
            setTimeout(() => {
                const el = document.getElementById(decodeURIComponent(window.location.hash.substring(1)));
                if (el) window.scrollTo({ top: el.offsetTop - CONFIG.navbarHeight, behavior: 'smooth' });
            }, 200);
        }
    } catch (err) { window.location.href = "/404.html"; }
}

loadContent();
window.addEventListener('popstate', loadContent);